import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';
import '../cloud/supabase_sync_service.dart';
import '../../data/providers/app_providers.dart';
import 'admin_sync_service.dart';
import 'analytics_service.dart';

final auditLogServiceProvider = Provider<AuditLogService>((ref) {
  return AuditLogService(ref);
});

/// Records who changed what for trust, debugging, and admin visibility.
class AuditLogService {
  AuditLogService(this.ref);

  final Ref ref;

  Future<void> log({
    required String action,
    required String entityType,
    int? entityId,
    String detail = '',
    Map<String, dynamic> meta = const {},
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    final payload = jsonEncode({
      'action': action,
      'entityType': entityType,
      'entityId': ?entityId,
      'detail': detail,
      'actorEmail': user?.email ?? '',
      'actorName': user?.name ?? '',
      ...meta,
    });

    await ref.read(analyticsServiceProvider).track(
          eventType: 'audit_$action',
          email: user?.email,
          name: user?.name,
          payload: payload,
        );

    try {
      await ref.read(supabaseSyncServiceProvider).mirrorAnalyticsEvent(
            eventType: 'audit_$action',
            userEmail: user?.email ?? '',
            userName: user?.name ?? '',
            plan: 'free',
            payload: payload,
          );
    } catch (_) {}

    ref.read(adminSyncServiceProvider).syncPendingEvents();
  }

  Future<void> logInvoiceStatusChange({
    required int invoiceId,
    required String fromStatus,
    required String toStatus,
    String invoiceNumber = '',
  }) =>
      log(
        action: 'invoice_status',
        entityType: 'invoice',
        entityId: invoiceId,
        detail: '$invoiceNumber: $fromStatus -> $toStatus',
        meta: {'fromStatus': fromStatus, 'toStatus': toStatus},
      );

  Future<void> logContractSigned({required int contractId, required String title}) =>
      log(action: 'contract_signed', entityType: 'contract', entityId: contractId, detail: title);

  Future<void> logAdminGranted({required String targetEmail}) =>
      log(action: 'admin_granted', entityType: 'user', detail: targetEmail);

  Future<void> logPaymentConfirmed({required String invoiceNumber, required String clientName}) =>
      log(action: 'payment_confirmed', entityType: 'invoice', detail: '$clientName paid $invoiceNumber');

  Future<void> logNotificationSent({required String toEmail, required String title}) =>
      log(action: 'notification_sent', entityType: 'notification', detail: '$title -> $toEmail');
}

final auditLogsProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).watchAnalytics(limit: 100).map(
        (events) => events.where((e) => e.eventType.startsWith('audit_')).toList(),
      );
});
