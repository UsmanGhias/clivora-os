import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../../data/providers/database_provider.dart';
import '../auth/auth_service.dart';
import '../cloud/cloud_notification_repository.dart';
import '../cloud/supabase_sync_service.dart';
import '../utils/currency_formatter.dart';

final milestoneServiceProvider = Provider<MilestoneService>((ref) => MilestoneService(ref));

class MilestoneStatuses {
  static const pending = 'pending';
  static const inProgress = 'in_progress';
  static const submitted = 'submitted';
  static const approved = 'approved';
  static const paid = 'paid';
  static const canceled = 'canceled';

  static const all = [pending, inProgress, submitted, approved, paid, canceled];

  static String label(String s) => s.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

class MilestoneService {
  MilestoneService(this.ref);
  final Ref ref;

  Future<int> create({
    required int projectId,
    required String title,
    String description = '',
    required double amount,
    required String currency,
    DateTime? dueDate,
  }) async {
    final owner = ref.read(authStateProvider).valueOrNull;
    if (owner == null) throw StateError('Sign in required');
    final db = ref.read(databaseProvider);
    final existing = await db.watchMilestonesForProject(owner.id, projectId).first;
    return db.into(db.projectMilestones).insert(
          ProjectMilestonesCompanion.insert(
            ownerUserId: owner.id,
            projectId: projectId,
            title: title.trim(),
            description: Value(description.trim()),
            amount: Value(amount),
            currency: Value(currency),
            dueDate: Value(dueDate),
            sortOrder: Value(existing.length),
          ),
        );
  }

  Future<void> updateStatus(ProjectMilestone milestone, String status) async {
    final owner = ref.read(authStateProvider).valueOrNull;
    if (owner == null) return;
    final db = ref.read(databaseProvider);
    await (db.update(db.projectMilestones)..where((t) => t.id.equals(milestone.id) & t.ownerUserId.equals(owner.id)))
        .write(
      ProjectMilestonesCompanion(
        status: Value(status),
        completedAt: Value(status == MilestoneStatuses.approved || status == MilestoneStatuses.paid ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
      ),
    );

    final project = await db.getProjectForUser(owner.id, milestone.projectId);
    final link = await (db.select(db.projectClientLinks)..where((t) => t.projectId.equals(milestone.projectId))).getSingleOrNull();
    if (link != null && project != null) {
      final toUid = await ref.read(supabaseSyncServiceProvider).uidForEmail(link.clientEmail);
      if (toUid != null) {
        await ref.read(cloudNotificationRepositoryProvider).sendToUid(
              toUid: toUid,
              title: 'Milestone update: ${milestone.title}',
              body: '${project.name} · ${MilestoneStatuses.label(status)} · ${formatCurrency(milestone.amount, symbol: currencySymbol(milestone.currency))}',
              kind: 'milestone',
            );
      }
    }
  }

  Future<int?> createInvoiceFromMilestone(ProjectMilestone milestone) async {
    final owner = ref.read(authStateProvider).valueOrNull;
    if (owner == null) return null;
    final db = ref.read(databaseProvider);
    final project = await db.getProjectForUser(owner.id, milestone.projectId);
    if (project == null) return null;

    final count = await db.watchInvoicesForUser(owner.id).first;
    final number = 'INV-M${milestone.id}-${count.length + 1}';
    final lineItems = '[{"description":"Milestone: ${milestone.title.replaceAll('"', "'")}","quantity":1,"unitPrice":${milestone.amount}}]';

    final invoiceId = await db.into(db.invoices).insert(
          InvoicesCompanion.insert(
            ownerUserId: owner.id,
            invoiceNumber: number,
            customerId: project.customerId,
            projectId: Value(project.id),
            status: const Value('draft'),
            subtotal: Value(milestone.amount),
            total: Value(milestone.amount),
            currency: Value(milestone.currency),
            lineItems: Value(lineItems),
          ),
        );

    await (db.update(db.projectMilestones)..where((t) => t.id.equals(milestone.id))).write(
          ProjectMilestonesCompanion(
            invoiceId: Value(invoiceId),
            status: const Value(MilestoneStatuses.submitted),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return invoiceId;
  }
}

final projectMilestonesProvider = StreamProvider.family<List<ProjectMilestone>, int>((ref, projectId) {
  final ownerId = ref.watch(authStateProvider).valueOrNull?.id;
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchMilestonesForProject(ownerId, projectId);
});
