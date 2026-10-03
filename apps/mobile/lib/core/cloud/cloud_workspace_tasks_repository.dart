import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';
import '../../data/database/user_scoped_queries.dart';
import 'supabase_auth_helper.dart';

final cloudWorkspaceTasksRepositoryProvider =
    Provider<CloudWorkspaceTasksRepository>((ref) {
  return CloudWorkspaceTasksRepository(ref);
});

/// Syncs Drift Tasks ↔ Supabase workspace_tasks (Phase 2). Flag-gated by callers.
class CloudWorkspaceTasksRepository {
  CloudWorkspaceTasksRepository(this.ref);

  final Ref ref;

  Future<bool> isEnabled() async {
    try {
      for (final key in ['workspace_tasks', 'phase2_workspace_tasks']) {
        final row = await SupabaseAuthHelper.client
            .from('app_feature_flags')
            .select('enabled')
            .eq('key', key)
            .maybeSingle();
        if (row?['enabled'] == true) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> pushTask({required int ownerUserId, required int localId}) async {
    if (!await isEnabled()) return;
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return;
    final row = await ref.read(databaseProvider).getTaskForUser(ownerUserId, localId);
    if (row == null) return;

    String? cloudCustomerId;
    String? cloudProjectId;
    if (row.customerId != null) {
      try {
        final c = await SupabaseAuthHelper.client
            .from('crm_customers')
            .select('id')
            .eq('owner_uid', uid)
            .eq('local_id', row.customerId!)
            .maybeSingle();
        cloudCustomerId = c?['id'] as String?;
      } catch (_) {}
    }
    if (row.projectId != null) {
      try {
        final p = await SupabaseAuthHelper.client
            .from('crm_projects')
            .select('id')
            .eq('owner_uid', uid)
            .eq('local_id', row.projectId!)
            .maybeSingle();
        cloudProjectId = p?['id'] as String?;
      } catch (_) {}
    }

    final payload = {
      'owner_uid': uid,
      'local_id': localId,
      'title': row.title,
      'description': row.description,
      'priority': row.priority,
      'status': row.status,
      'due_at': row.dueDate?.toUtc().toIso8601String(),
      'completed': row.completed,
      'customer_id': cloudCustomerId,
      'project_id': cloudProjectId,
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
    };

    try {
      final existing = await SupabaseAuthHelper.client
          .from('workspace_tasks')
          .select('id')
          .eq('owner_uid', uid)
          .eq('local_id', localId)
          .maybeSingle();
      if (existing != null) {
        await SupabaseAuthHelper.client
            .from('workspace_tasks')
            .update(payload)
            .eq('id', existing['id']);
      } else {
        await SupabaseAuthHelper.client.from('workspace_tasks').insert(payload);
      }
    } catch (e) {
      debugPrint('workspace_tasks push failed: $e');
      rethrow;
    }
  }

  Future<void> pullTasks({required int ownerUserId}) async {
    if (!await isEnabled()) return;
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return;
    final db = ref.read(databaseProvider);
    final rows = await SupabaseAuthHelper.client
        .from('workspace_tasks')
        .select()
        .eq('owner_uid', uid);
    for (final raw in rows as List) {
      final map = Map<String, dynamic>.from(raw as Map);
      final localId = (map['local_id'] as num?)?.toInt();
      final cloudUpdated =
          DateTime.tryParse(map['updated_at'] as String? ?? '')?.toLocal() ?? DateTime.now();
      final dueRaw = map['due_at'] as String?;
      final due = dueRaw != null ? DateTime.tryParse(dueRaw)?.toLocal() : null;

      // Existing local row → update when cloud is newer.
      if (localId != null && localId > 0) {
        final existing = await db.getTaskForUser(ownerUserId, localId);
        if (existing != null) {
          if (cloudUpdated.isAfter(existing.updatedAt)) {
            await db.updateTask(
              existing.copyWith(
                title: map['title'] as String? ?? existing.title,
                description: map['description'] as String? ?? existing.description,
                priority: map['priority'] as String? ?? existing.priority,
                status: map['status'] as String? ?? existing.status,
                completed: map['completed'] as bool? ?? existing.completed,
                dueDate: Value(due ?? existing.dueDate),
                updatedAt: cloudUpdated,
              ),
            );
          }
          continue;
        }
        // local_id points at a row that no longer exists locally → fall through
        // and recreate it so cloud and device converge (owner-scoped).
      }

      // Cloud-only task (no local_id, or local row missing): insert into this
      // user's Drift database, then stamp local_id back to the cloud row so the
      // pair reconciles without duplicating on the next pull. (APP-006)
      final cloudId = map['id'] as String?;
      final newLocalId = await db.insertTask(
        TasksCompanion.insert(
          ownerUserId: ownerUserId,
          title: (map['title'] as String?)?.trim().isNotEmpty == true
              ? map['title'] as String
              : 'Task',
          description: Value(map['description'] as String? ?? ''),
          priority: Value(map['priority'] as String? ?? 'medium'),
          status: Value(map['status'] as String? ?? 'pending'),
          completed: Value(map['completed'] as bool? ?? false),
          dueDate: Value(due),
          updatedAt: Value(cloudUpdated),
        ),
      );
      if (cloudId != null) {
        try {
          await SupabaseAuthHelper.client
              .from('workspace_tasks')
              .update({'local_id': newLocalId})
              .eq('id', cloudId);
        } catch (e) {
          debugPrint('stamp workspace_tasks local_id: $e');
        }
      }
    }
  }
}
