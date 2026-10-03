import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import 'backup_restore_service.dart';

final cloudCrmBackupServiceProvider = Provider<CloudCrmBackupService>((ref) {
  return CloudCrmBackupService(ref);
});

/// True when cloud CRM backup is overdue (never backed up or older than 7 days).
final cloudBackupReminderProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateProvider);
  return ref.read(cloudCrmBackupServiceProvider).shouldRemindBackup();
});

/// Uploads / restores CRM JSON to Supabase so reinstall + sign-in can recover data.
class CloudCrmBackupService {
  CloudCrmBackupService(this.ref);

  final Ref ref;
  static const _lastBackupKey = 'clivora_last_cloud_backup_at';

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastBackupKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<bool> shouldRemindBackup() async {
    final last = await lastBackupAt();
    if (last == null) return true;
    return DateTime.now().difference(last) > const Duration(days: 7);
  }

  Future<void> uploadCurrentWorkspace() async {
    final client = _client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) {
      throw StateError('Sign in with cloud account to use cloud backup');
    }

    final payload = await ref.read(backupRestoreServiceProvider).exportWorkspace();
    final encoded = jsonEncode(payload);
    final checksum = payload['checksum'] as String? ?? '';

    await client.from('crm_cloud_backups').insert({
      'user_id': uid,
      'schema_version': payload['schemaVersion'] ?? 1,
      'payload': payload,
      'byte_size': utf8.encode(encoded).length,
      'checksum': checksum,
    });

    // Keep only the latest 5 backups per user
    final rows = await client
        .from('crm_cloud_backups')
        .select('id, created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.length > 5) {
      final stale = list.skip(5).map((e) => e['id'] as String).toList();
      for (final id in stale) {
        await client.from('crm_cloud_backups').delete().eq('id', id);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());
  }

  Future<Map<String, dynamic>?> fetchLatestBackup() async {
    final client = _client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) return null;

    final row = await client
        .from('crm_cloud_backups')
        .select('payload, created_at, byte_size')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    final payload = row['payload'];
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  }

  /// After sign-in on a fresh install: restore cloud CRM if local workspace is empty.
  Future<bool> restoreIfLocalEmpty() async {
    try {
      final ownerId = ref.read(authStateProvider).valueOrNull?.id;
      if (ownerId == null) return false;

      final db = ref.read(databaseProvider);
      final customers = await db.watchCustomersForUser(ownerId).first;
      final projects = await db.watchProjectsForUser(ownerId).first;
      final invoices = await db.watchInvoicesForUser(ownerId).first;
      if (customers.isNotEmpty || projects.isNotEmpty || invoices.isNotEmpty) {
        return false;
      }

      final backup = await fetchLatestBackup();
      if (backup == null) return false;

      await ref.read(backupRestoreServiceProvider).importWorkspace(backup);
      debugPrint('Cloud CRM backup restored after empty local workspace');
      return true;
    } catch (e, st) {
      debugPrint('Cloud CRM restore skipped: $e\n$st');
      return false;
    }
  }
}
