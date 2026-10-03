import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/providers/database_provider.dart';
import '../auth/auth_service.dart';
import '../cloud/cloud_invoice_repository.dart';
import '../cloud/cloud_notification_repository.dart';
import '../cloud/supabase_sync_service.dart';
import '../constants/invoice_statuses.dart';

final disputeServiceProvider = Provider<DisputeService>((ref) => DisputeService(ref));

class DisputeService {
  DisputeService(this.ref);
  final Ref ref;

  Future<String?> raiseDispute({
    required Invoice invoice,
    required String reason,
    required String raisedByEmail,
  }) async {
    final trimmed = reason.trim();
    if (trimmed.length < 8) return 'Describe the issue (at least 8 characters).';
    if (invoice.status == InvoiceStatuses.paid || invoice.status == InvoiceStatuses.canceled) {
      return 'This invoice cannot be disputed.';
    }

    final db = ref.read(databaseProvider);
    await db.into(db.invoiceDisputes).insert(
          InvoiceDisputesCompanion.insert(
            ownerUserId: invoice.ownerUserId,
            invoiceId: invoice.id,
            reason: trimmed,
            raisedByEmail: Value(raisedByEmail.trim().toLowerCase()),
          ),
        );

    await db.updateInvoice(invoice.copyWith(status: InvoiceStatuses.disputed, updatedAt: DateTime.now()));

    final toUid = await ref.read(supabaseSyncServiceProvider).uidForEmail(
          (await db.getUser(invoice.ownerUserId))?.email ?? '',
        );
    if (toUid != null) {
      await ref.read(cloudNotificationRepositoryProvider).sendToUid(
            toUid: toUid,
            title: 'Invoice disputed: ${invoice.invoiceNumber}',
            body: trimmed,
            kind: 'dispute',
          );
    }
    return null;
  }

  Future<String?> raiseDisputeOnCloudShare({
    required CloudInvoiceShare share,
    required String reason,
    required String raisedByEmail,
  }) async {
    final trimmed = reason.trim();
    if (trimmed.length < 8) return 'Describe the issue (at least 8 characters).';
    if (share.status == InvoiceStatuses.paid || share.status == InvoiceStatuses.canceled) {
      return 'This invoice cannot be disputed.';
    }

    try {
      await ref.read(cloudInvoiceRepositoryProvider).updateShareStatus(
            shareId: share.shareId,
            status: InvoiceStatuses.disputed,
          );
    } catch (_) {}

    if (share.freelancerUid.isNotEmpty) {
      await ref.read(cloudNotificationRepositoryProvider).sendToUid(
            toUid: share.freelancerUid,
            title: 'Invoice disputed: ${share.invoiceNumber}',
            body: trimmed,
            kind: 'dispute',
          );
    }
    return null;
  }

  Future<String?> resolveDispute({
    required InvoiceDispute dispute,
    required String resolution,
    required Invoice invoice,
  }) async {
    final owner = ref.read(authStateProvider).valueOrNull;
    if (owner == null || owner.id != dispute.ownerUserId) return 'Not allowed';
    final note = resolution.trim();
    if (note.length < 4) return 'Add a short resolution note.';

    final db = ref.read(databaseProvider);
    await (db.update(db.invoiceDisputes)..where((t) => t.id.equals(dispute.id))).write(
          InvoiceDisputesCompanion(
            status: const Value('resolved'),
            resolution: Value(note),
            resolvedAt: Value(DateTime.now()),
          ),
        );
    await db.updateInvoice(invoice.copyWith(status: InvoiceStatuses.sent, updatedAt: DateTime.now()));

    if (dispute.raisedByEmail.isNotEmpty) {
      final toUid = await ref.read(supabaseSyncServiceProvider).uidForEmail(dispute.raisedByEmail);
      if (toUid != null) {
        await ref.read(cloudNotificationRepositoryProvider).sendToUid(
              toUid: toUid,
              title: 'Dispute resolved: ${invoice.invoiceNumber}',
              body: note,
              kind: 'dispute',
            );
      }
    }
    return null;
  }
}
