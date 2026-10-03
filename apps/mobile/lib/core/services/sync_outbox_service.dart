import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show HttpException, HandshakeException, SocketException;
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../cloud/cloud_calendar_events_repository.dart';
import '../cloud/cloud_crm_enrichment_repository.dart';
import '../cloud/cloud_crm_repository.dart';
import '../cloud/cloud_invoice_repository.dart';
import '../cloud/cloud_notification_repository.dart';
import '../cloud/cloud_project_repository.dart';
import '../cloud/cloud_workspace_tasks_repository.dart';
import '../cloud/supabase_auth_helper.dart';
import '../auth/auth_service.dart';
import '../../core/utils/crm_refresh.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import 'admin_sync_service.dart';
import 'analytics_service.dart';
import 'audit_log_service.dart';
import 'connectivity_service.dart';
import 'tracking_service.dart';

final syncOutboxServiceProvider = Provider<SyncOutboxService>((ref) {
  return SyncOutboxService(ref);
});

/// Offline-first queue for cloud operations with Drift durability, retries, and conflicts.
class SyncOutboxService {
  SyncOutboxService(this.ref);

  final Ref ref;
  static const _legacyOutboxKey = 'clivora_sync_outbox_v1';
  static const _legacyConflictKey = 'clivora_invoice_conflicts_v1';
  static const _migratedFlag = 'clivora_sync_outbox_migrated_v18';
  static const _maxRetries = 10;
  static const _uuid = Uuid();

  bool _migrating = false;
  bool _processing = false;

  AppDatabase get _db => ref.read(databaseProvider);

  int? get _localOwnerId => ref.read(authStateProvider).valueOrNull?.id;

  Future<void> ensureMigrated() async {
    if (_migrating) return;
    _migrating = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migratedFlag) == true) return;

      final raw = prefs.getString(_legacyOutboxKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final list = jsonDecode(raw) as List;
          for (final e in list) {
            final item = SyncOutboxItem.fromJson(Map<String, dynamic>.from(e as Map));
            await _db.insertSyncOutbox(
              SyncOutboxEntriesCompanion.insert(
                ownerUserId: Value(_localOwnerId),
                operationId: item.operationId.isNotEmpty ? item.operationId : _uuid.v4(),
                kind: item.kind,
                payloadJson: Value(jsonEncode(item.payload)),
                status: const Value('pending'),
                retries: Value(item.retries),
                createdAt: Value(item.createdAt),
                updatedAt: Value(DateTime.now()),
                isTombstone: Value(item.isTombstone),
              ),
            );
          }
        } catch (e) {
          debugPrint('Outbox prefs migration parse error: $e');
        }
        await prefs.remove(_legacyOutboxKey);
      }

      final conflictRaw = prefs.getString(_legacyConflictKey);
      if (conflictRaw != null && conflictRaw.isNotEmpty) {
        try {
          final list = jsonDecode(conflictRaw) as List;
          for (final e in list) {
            final m = Map<String, dynamic>.from(e as Map);
            final entityType = (m['entityType'] as String?) ?? 'invoice';
            final localId = (m['localId'] as num?)?.toInt() ??
                (m['localInvoiceId'] as num?)?.toInt();
            if (localId == null) continue;
            await _db.insertSyncConflict(
              SyncConflictEntriesCompanion.insert(
                ownerUserId: Value(_localOwnerId),
                entityType: entityType,
                localId: localId,
                localStatus: Value(m['localStatus'] as String? ?? ''),
                cloudStatus: Value(m['cloudStatus'] as String? ?? ''),
                shareId: Value(m['shareId'] as String?),
              ),
            );
          }
        } catch (e) {
          debugPrint('Conflict prefs migration parse error: $e');
        }
        await prefs.remove(_legacyConflictKey);
      }

      await prefs.setBool(_migratedFlag, true);
    } finally {
      _migrating = false;
    }
  }

  Future<List<Map<String, dynamic>>> pendingConflicts() async {
    await ensureMigrated();
    final rows = await _db.listSyncConflicts(ownerUserId: _localOwnerId);
    return rows
        .map(
          (r) => {
            'id': r.id,
            'entityType': r.entityType,
            'localId': r.localId,
            'localInvoiceId': r.entityType == 'invoice' ? r.localId : null,
            'localStatus': r.localStatus,
            'cloudStatus': r.cloudStatus,
            'shareId': r.shareId,
            'cloudPayloadJson': r.cloudPayloadJson,
            'at': r.createdAt.toIso8601String(),
          },
        )
        .toList();
  }

  Future<void> addInvoiceConflict({
    required int localInvoiceId,
    required String localStatus,
    required String cloudStatus,
    required String shareId,
  }) async {
    await addEntityConflict(
      entityType: 'invoice',
      localId: localInvoiceId,
      localStatus: localStatus,
      cloudStatus: cloudStatus,
      shareId: shareId,
    );
  }

  Future<void> addEntityConflict({
    required String entityType,
    required int localId,
    required String localStatus,
    required String cloudStatus,
    String? shareId,
    String? cloudPayloadJson,
  }) async {
    await ensureMigrated();
    await _db.deleteSyncConflict(
      entityType: entityType,
      localId: localId,
      ownerUserId: _localOwnerId,
    );
    await _db.insertSyncConflict(
      SyncConflictEntriesCompanion.insert(
        ownerUserId: Value(_localOwnerId),
        entityType: entityType,
        localId: localId,
        localStatus: Value(localStatus),
        cloudStatus: Value(cloudStatus),
        shareId: Value(shareId),
        cloudPayloadJson: Value(cloudPayloadJson),
      ),
    );
    ref.read(syncFailureMessageProvider.notifier).state =
        '${entityType[0].toUpperCase()}${entityType.substring(1)} sync conflict - open Sync Center.';
  }

  Future<List<Map<String, dynamic>>> pendingByEntity(String entityType) async {
    final all = await pendingConflicts();
    return all.where((e) => (e['entityType'] ?? 'invoice') == entityType).toList();
  }

  Future<void> clearConflict(int localInvoiceId) async {
    await clearEntityConflict(entityType: 'invoice', localId: localInvoiceId);
  }

  Future<void> clearEntityConflict({
    required String entityType,
    required int localId,
  }) async {
    await ensureMigrated();
    await _db.deleteSyncConflict(
      entityType: entityType,
      localId: localId,
      ownerUserId: _localOwnerId,
    );
  }

  Future<void> resolveConflictKeepLocal({
    required int localInvoiceId,
    required String shareId,
    required String clientEmail,
    String? clientUid,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final invoice = await _db.getInvoiceForUser(user.id, localInvoiceId);
    if (invoice == null) return;
    await ref.read(cloudInvoiceRepositoryProvider).syncInvoiceToClient(
          freelancer: user,
          invoice: invoice,
          clientEmail: clientEmail,
          clientUid: clientUid,
        );
    await clearConflict(localInvoiceId);
  }

  Future<void> resolveConflictTakeCloud({
    required int localInvoiceId,
    required String cloudStatus,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final invoice = await _db.getInvoiceForUser(user.id, localInvoiceId);
    if (invoice == null) return;
    await _db.updateInvoice(
      invoice.copyWith(status: cloudStatus, updatedAt: DateTime.now()),
    );
    await clearConflict(localInvoiceId);
    ref.invalidate(invoicesProvider(null));
  }

  /// Resolve CRM conflicts with full Keep-local upload / Take-cloud apply.
  Future<void> resolveEntityConflict({
    required String entityType,
    required int localId,
    required bool takeCloud,
    String cloudStatus = '',
    String? cloudPayloadJson,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    if (takeCloud) {
      if (entityType == 'project') {
        final project = await _db.getProjectForUser(user.id, localId);
        if (project != null) {
          Map<String, dynamic>? cloud;
          if (cloudPayloadJson != null && cloudPayloadJson.isNotEmpty) {
            try {
              cloud = Map<String, dynamic>.from(jsonDecode(cloudPayloadJson) as Map);
            } catch (_) {}
          }
          await _db.updateProject(
            project.copyWith(
              name: cloud?['name'] as String? ?? project.name,
              description: cloud?['description'] as String? ?? project.description,
              budget: (cloud?['budget'] as num?)?.toDouble() ?? project.budget,
              currency: cloud?['currency'] as String? ?? project.currency,
              status: (cloud?['status'] as String?) ??
                  (cloudStatus.isNotEmpty ? cloudStatus : project.status),
              priority: cloud?['priority'] as String? ?? project.priority,
              updatedAt: DateTime.now(),
            ),
          );
          ref.invalidate(projectsProvider(const ProjectFilter()));
        }
      } else if (entityType == 'customer') {
        final customer = await _db.getCustomerForUser(user.id, localId);
        if (customer != null) {
          Map<String, dynamic>? cloud;
          if (cloudPayloadJson != null && cloudPayloadJson.isNotEmpty) {
            try {
              cloud = Map<String, dynamic>.from(jsonDecode(cloudPayloadJson) as Map);
            } catch (_) {}
          }
          if (cloud != null) {
            await _db.updateCustomer(
              customer.copyWith(
                contactPerson: cloud['name'] as String? ??
                    cloud['contact_person'] as String? ??
                    customer.contactPerson,
                emails: cloud['email'] != null
                    ? jsonEncode([cloud['email']])
                    : (cloud['emails'] is String
                        ? cloud['emails'] as String
                        : customer.emails),
                phones: cloud['phone'] != null
                    ? jsonEncode([cloud['phone']])
                    : (cloud['phones'] is String
                        ? cloud['phones'] as String
                        : customer.phones),
                company: cloud['company'] as String? ?? customer.company,
                notes: cloud['notes'] as String? ?? customer.notes,
                updatedAt: DateTime.now(),
              ),
            );
          }
          ref.invalidate(customersProvider(null));
        }
      } else if (entityType == 'invoice' && cloudStatus.isNotEmpty) {
        await resolveConflictTakeCloud(localInvoiceId: localId, cloudStatus: cloudStatus);
        return;
      }
    } else {
      // Keep local → re-upload complete local record.
      if (entityType == 'project') {
        await enqueue(
          SyncOutboxItem(
            kind: 'crm_project',
            payload: {'localId': localId},
            ownerUserId: user.id,
          ),
        );
        await processQueue();
      } else if (entityType == 'customer') {
        await enqueue(
          SyncOutboxItem(
            kind: 'crm_customer',
            payload: {'localId': localId},
            ownerUserId: user.id,
          ),
        );
        await processQueue();
      } else if (entityType == 'invoice') {
        await enqueue(
          SyncOutboxItem(
            kind: 'crm_invoice',
            payload: {'localId': localId},
            ownerUserId: user.id,
          ),
        );
        await processQueue();
      }
    }

    await clearEntityConflict(entityType: entityType, localId: localId);
  }

  Future<void> enqueue(SyncOutboxItem item) async {
    await ensureMigrated();
    final ownerId = item.ownerUserId ?? _localOwnerId;
    await _db.insertSyncOutbox(
      SyncOutboxEntriesCompanion.insert(
        ownerUserId: Value(ownerId),
        operationId: item.operationId.isNotEmpty ? item.operationId : _uuid.v4(),
        kind: item.kind,
        payloadJson: Value(jsonEncode(item.payload)),
        status: const Value('pending'),
        retries: Value(item.retries),
        createdAt: Value(item.createdAt),
        updatedAt: Value(DateTime.now()),
        isTombstone: Value(item.isTombstone),
      ),
    );
    _updateBanner();
    if (SupabaseAuthHelper.currentUid != null &&
        await ref.read(connectivityServiceProvider).isOnlineNow()) {
      await processQueue();
    }
  }

  bool _isNetworkDropout(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException ||
        error is HandshakeException) {
      return true;
    }
    final s = error.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('timeoutexception') ||
        s.contains('network is unreachable') ||
        s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('connection closed') ||
        s.contains('failed host lookup') ||
        s.contains('software caused connection abort') ||
        s.contains('handshake failed') ||
        s.contains('clientexception');
  }

  /// Recovers any outbox rows that were marked 'processing' but left stranded
  /// by a process kill or crash mid-drain (> 5 minutes ago).
  Future<void> reapStrandedProcessingRows() async {
    try {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(minutes: 5));
      final active = await _db.listActiveOutbox(ownerUserId: _localOwnerId);
      for (final row in active) {
        if (row.status == 'processing' && row.updatedAt.isBefore(cutoff)) {
          debugPrint('Reaping stranded outbox row ${row.operationId} back to pending');
          await _db.updateSyncOutbox(
            row.copyWith(
              status: 'pending',
              updatedAt: now,
              lastError: const Value('Recovered from interrupted drain'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error reaping stranded outbox rows: $e');
    }
  }

  Future<void> processQueue() async {
    if (SupabaseAuthHelper.currentUid == null) return;
    if (_processing) return;
    _processing = true;
    try {
      await ensureMigrated();
      await reapStrandedProcessingRows();
      final due = await _db.listDueOutbox(ownerUserId: _localOwnerId);
      if (due.isEmpty) {
        await _updateBanner();
        return;
      }

      for (final row in due) {
        final processing = row.copyWith(
          status: 'processing',
          updatedAt: DateTime.now(),
        );
        await _db.updateSyncOutbox(processing);

        try {
          final item = SyncOutboxItem.fromRow(row);
          final result = await _execute(item);
          if (result == _ExecResult.success) {
            await _db.updateSyncOutbox(
              processing.copyWith(
                status: 'completed',
                updatedAt: DateTime.now(),
                completedAt: Value(DateTime.now()),
                lastError: const Value(null),
              ),
            );
          } else if (result == _ExecResult.permanentFailure) {
            await _db.updateSyncOutbox(
              processing.copyWith(
                status: 'permanently_failed',
                updatedAt: DateTime.now(),
                lastError: const Value('Unknown or unsupported operation'),
              ),
            );
          } else {
            if (row.retries >= _maxRetries) {
              await _db.updateSyncOutbox(
                processing.copyWith(
                  status: 'permanently_failed',
                  retries: row.retries,
                  updatedAt: DateTime.now(),
                  lastError: const Value('Max retries exceeded'),
                ),
              );
            } else {
              final retries = row.retries + 1;
              final delay = _backoff(retries);
              await _db.updateSyncOutbox(
                processing.copyWith(
                  status: 'retrying',
                  retries: retries,
                  nextAttemptAt: Value(DateTime.now().add(delay)),
                  updatedAt: DateTime.now(),
                  lastError: const Value('Transient failure - will retry'),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Sync outbox item failed: $e');
          if (_isNetworkDropout(e)) {
            // Network transport failure: do NOT burn user retry budget.
            await _db.updateSyncOutbox(
              processing.copyWith(
                status: 'retrying',
                nextAttemptAt: Value(DateTime.now().add(const Duration(seconds: 45))),
                updatedAt: DateTime.now(),
                lastError: Value('Waiting for network connectivity: $e'),
              ),
            );
            // Cease further drain attempts while offline to conserve battery
            break;
          }

          if (row.retries >= _maxRetries) {
            await _db.updateSyncOutbox(
              processing.copyWith(
                status: 'permanently_failed',
                retries: row.retries,
                updatedAt: DateTime.now(),
                lastError: Value(e.toString()),
              ),
            );
          } else {
            final retries = row.retries + 1;
            final delay = _backoff(retries);
            await _db.updateSyncOutbox(
              processing.copyWith(
                status: 'retrying',
                retries: retries,
                nextAttemptAt: Value(DateTime.now().add(delay)),
                updatedAt: DateTime.now(),
                lastError: Value(e.toString()),
              ),
            );
          }
        }
      }

      await _db.clearCompletedOutboxOlderThan(const Duration(days: 7));
      await _updateBanner();
    } finally {
      _processing = false;
    }
  }

  Duration _backoff(int retries) {
    final seconds = min(300, pow(2, retries).toInt());
    return Duration(seconds: seconds);
  }

  Future<void> _updateBanner() async {
    final pending = await pendingCount();
    final failed = await permanentlyFailedCount();
    final conflicts = (await pendingConflicts()).length;
    // Only surface actionable problems in the shell banner. Routine pending
    // work is visible in Sync Center - avoids "2 sync in progress" double UI
    // with OfflineStatusBar / Hub cards.
    if (conflicts > 0) {
      ref.read(syncFailureMessageProvider.notifier).state =
          '$conflicts sync conflict(s). Open Sync Center to resolve.';
    } else if (failed > 0) {
      ref.read(syncFailureMessageProvider.notifier).state =
          '$failed change(s) permanently failed. Open Sync Center.';
    } else {
      ref.read(syncFailureMessageProvider.notifier).state = null;
    }
    // Keep pending count available for Sync Center; do not set a pending banner.
    if (pending > 0 && conflicts == 0 && failed == 0) {
      debugPrint('Sync outbox pending=$pending (banner suppressed)');
    }
  }

  Future<void> retryPermanentlyFailed() async {
    await ensureMigrated();
    final rows = await _db.listActiveOutbox(ownerUserId: _localOwnerId);
    for (final row in rows.where((r) => r.status == 'permanently_failed')) {
      if (_isUnknownKind(row.kind)) continue; // never retry unknown
      await _db.updateSyncOutbox(
        row.copyWith(
          status: 'pending',
          retries: 0,
          nextAttemptAt: const Value(null),
          updatedAt: DateTime.now(),
          lastError: const Value(null),
        ),
      );
    }
    await processQueue();
  }

  Future<void> retryOne(int id) async {
    await ensureMigrated();
    final rows = await _db.listActiveOutbox(ownerUserId: _localOwnerId);
    final matches = rows.where((r) => r.id == id);
    if (matches.isEmpty) return;
    final row = matches.first;
    if (_isUnknownKind(row.kind)) return;
    await _db.updateSyncOutbox(
      row.copyWith(
        status: 'pending',
        nextAttemptAt: const Value(null),
        updatedAt: DateTime.now(),
      ),
    );
    await processQueue();
  }

  bool _isUnknownKind(String kind) {
    const known = {
      'notification',
      'analytics',
      'admin_sync',
      'invoice_sync',
      'project_share',
      'crm_customer',
      'crm_project',
      'crm_invoice',
      'crm_sync_all',
      'crm_customer_delete',
      'crm_project_delete',
      'crm_invoice_delete',
      'workspace_task',
      'calendar_event',
    };
    return !known.contains(kind);
  }

  Future<void> reconcileInvoiceShares() async {
    final uid = SupabaseAuthHelper.currentUid;
    final user = ref.read(authStateProvider).valueOrNull;
    if (uid == null || user == null) return;

    try {
      final rows = await SupabaseAuthHelper.client
          .from('invoice_shares')
          .select()
          .eq('freelancer_uid', uid);
      final db = _db;
      for (final row in rows as List) {
        final localId = (row['local_invoice_id'] as num?)?.toInt();
        if (localId == null || localId <= 0) continue;
        final cloudStatus = row['status'] as String? ?? 'draft';
        final cloudUpdated = DateTime.tryParse(row['updated_at'] as String? ?? '');
        final invoice = await db.getInvoiceForUser(user.id, localId);
        if (invoice == null) continue;

        if (cloudUpdated != null && cloudUpdated.isAfter(invoice.updatedAt)) {
          if (invoice.status != cloudStatus) {
            if (cloudStatus == 'paid') {
              await db.updateInvoice(
                invoice.copyWith(status: cloudStatus, updatedAt: cloudUpdated.toLocal()),
              );
              final method = row['payment_method'] as String? ?? '';
              final clientEmail = row['client_email'] as String? ?? '';
              await ref.read(trackingServiceProvider).logStatusChange(
                    entityType: 'invoice',
                    entityId: invoice.id,
                    status: 'paid',
                    note: method.isNotEmpty
                        ? 'Client paid via $method'
                        : 'Client confirmed payment',
                  );
              await ref.read(auditLogServiceProvider).logPaymentConfirmed(
                    invoiceNumber: invoice.invoiceNumber,
                    clientName: clientEmail,
                  );
              await clearConflict(invoice.id);
              ref.invalidate(invoicesProvider(null));
            } else if (invoice.status == 'paid') {
              await ref.read(cloudInvoiceRepositoryProvider).syncInvoiceToClient(
                    freelancer: user,
                    invoice: invoice,
                    clientEmail: row['client_email'] as String? ?? '',
                    clientUid: row['client_uid'] as String?,
                  );
            } else {
              await addInvoiceConflict(
                localInvoiceId: invoice.id,
                localStatus: invoice.status,
                cloudStatus: cloudStatus,
                shareId: row['share_id'] as String? ?? '',
              );
            }
          }
        } else if (invoice.updatedAt.isAfter(cloudUpdated ?? DateTime(2000))) {
          await ref.read(cloudInvoiceRepositoryProvider).syncInvoiceToClient(
                freelancer: user,
                invoice: invoice,
                clientEmail: row['client_email'] as String? ?? '',
                clientUid: row['client_uid'] as String?,
              );
        }
      }
    } catch (e) {
      debugPrint('Invoice reconciliation failed: $e');
    }
  }

  Future<_ExecResult> _execute(SyncOutboxItem item) async {
    switch (item.kind) {
      case 'notification':
        final toUid = item.payload['toUid'] as String?;
        if (toUid != null && toUid.isNotEmpty) {
          await ref.read(cloudNotificationRepositoryProvider).sendToUid(
                toUid: toUid,
                title: item.payload['title'] as String? ?? '',
                body: item.payload['body'] as String? ?? '',
                kind: item.payload['kind'] as String? ?? 'info',
              );
        } else {
          await ref.read(cloudNotificationRepositoryProvider).send(
                toEmail: item.payload['toEmail'] as String? ?? '',
                title: item.payload['title'] as String? ?? '',
                body: item.payload['body'] as String? ?? '',
                kind: item.payload['kind'] as String? ?? 'info',
              );
        }
        return _ExecResult.success;
      case 'analytics':
        await ref.read(analyticsServiceProvider).track(
              eventType: item.payload['eventType'] as String? ?? 'event',
              email: item.payload['email'] as String?,
              name: item.payload['name'] as String?,
              plan: item.payload['plan'] as String? ?? 'free',
              amount: (item.payload['amount'] as num?)?.toDouble() ?? 0,
              payload: item.payload['payload'] as String? ?? '{}',
            );
        return _ExecResult.success;
      case 'admin_sync':
        await ref.read(adminSyncServiceProvider).flushPendingEvents();
        return _ExecResult.success;
      case 'invoice_sync':
        final user = ref.read(authStateProvider).valueOrNull;
        if (user == null) return _ExecResult.transientFailure;
        final invoiceId = (item.payload['invoiceId'] as num?)?.toInt();
        if (invoiceId == null) return _ExecResult.transientFailure;
        final invoice = await _db.getInvoiceForUser(user.id, invoiceId);
        if (invoice == null) {
          // Deleted locally - treat delete tombstone as success once noted.
          if (item.isTombstone) return _ExecResult.success;
          return _ExecResult.transientFailure;
        }
        await ref.read(cloudInvoiceRepositoryProvider).syncInvoiceToClient(
              freelancer: user,
              invoice: invoice,
              clientEmail: item.payload['clientEmail'] as String? ?? '',
              clientUid: item.payload['clientUid'] as String?,
            );
        return _ExecResult.success;
      case 'project_share':
        final user = ref.read(authStateProvider).valueOrNull;
        if (user == null) return _ExecResult.transientFailure;
        final projectId = (item.payload['projectId'] as num?)?.toInt();
        if (projectId == null) return _ExecResult.transientFailure;
        final project = await _db.getProjectForUser(user.id, projectId);
        if (project == null) {
          if (item.isTombstone) return _ExecResult.success;
          return _ExecResult.transientFailure;
        }
        await ref.read(cloudProjectRepositoryProvider).shareHybrid(
              freelancer: user,
              clientEmail: item.payload['clientEmail'] as String? ?? '',
              localProjectId: projectId,
              project: project,
            );
        return _ExecResult.success;
      case 'crm_customer':
        final user = ref.read(authStateProvider).valueOrNull;
        final localId = (item.payload['localId'] as num?)?.toInt();
        if (user == null || localId == null) return _ExecResult.transientFailure;
        await ref.read(cloudCrmRepositoryProvider).pushCustomer(
              ownerUserId: user.id,
              localId: localId,
            );
        return _ExecResult.success;
      case 'crm_project':
        final user = ref.read(authStateProvider).valueOrNull;
        final localId = (item.payload['localId'] as num?)?.toInt();
        if (user == null || localId == null) return _ExecResult.transientFailure;
        await ref.read(cloudCrmRepositoryProvider).pushProject(
              ownerUserId: user.id,
              localId: localId,
            );
        return _ExecResult.success;
      case 'crm_invoice':
        final user = ref.read(authStateProvider).valueOrNull;
        final localId = (item.payload['localId'] as num?)?.toInt();
        if (user == null || localId == null) return _ExecResult.transientFailure;
        await ref.read(cloudCrmRepositoryProvider).pushInvoice(
              ownerUserId: user.id,
              localId: localId,
            );
        return _ExecResult.success;
      case 'crm_sync_all':
        await ref.read(cloudCrmRepositoryProvider).syncAllForSignedInUser();
        await ref.read(cloudCrmEnrichmentRepositoryProvider).syncPullSafe();
        final taskUser = ref.read(authStateProvider).valueOrNull;
        if (taskUser != null) {
          await ref.read(cloudWorkspaceTasksRepositoryProvider).pullTasks(
                ownerUserId: taskUser.id,
              );
        }
        return _ExecResult.success;
      case 'workspace_task':
        final user = ref.read(authStateProvider).valueOrNull;
        final localId = (item.payload['localId'] as num?)?.toInt();
        if (user == null || localId == null) return _ExecResult.transientFailure;
        if (item.isTombstone) {
          final uid = SupabaseAuthHelper.currentUid;
          if (uid != null) {
            try {
              await SupabaseAuthHelper.client
                  .from('workspace_tasks')
                  .delete()
                  .eq('owner_uid', uid)
                  .eq('local_id', localId);
            } catch (e) {
              debugPrint('workspace_task tombstone: $e');
            }
          }
          return _ExecResult.success;
        }
        await ref.read(cloudWorkspaceTasksRepositoryProvider).pushTask(
              ownerUserId: user.id,
              localId: localId,
            );
        return _ExecResult.success;
      case 'calendar_event':
        // Payload: title + startsAt ISO; cloud calendar when flag on.
        final title = item.payload['title'] as String?;
        final startsAtRaw = item.payload['startsAt'] as String?;
        if (title == null || startsAtRaw == null) return _ExecResult.permanentFailure;
        final startsAt = DateTime.tryParse(startsAtRaw);
        if (startsAt == null) return _ExecResult.permanentFailure;
        await ref.read(cloudCalendarEventsRepositoryProvider).upsertEvent(
              title: title,
              startsAt: startsAt,
              localId: (item.payload['localId'] as num?)?.toInt(),
            );
        return _ExecResult.success;
      case 'crm_customer_delete':
      case 'crm_project_delete':
      case 'crm_invoice_delete':
        final localId = (item.payload['localId'] as num?)?.toInt();
        if (localId == null) return _ExecResult.permanentFailure;
        try {
          if (item.kind == 'crm_customer_delete') {
            await ref.read(cloudCrmRepositoryProvider).deleteCustomerCloud(localId: localId);
          } else if (item.kind == 'crm_project_delete') {
            await ref.read(cloudCrmRepositoryProvider).deleteProjectCloud(localId: localId);
          } else {
            await ref.read(cloudCrmRepositoryProvider).deleteInvoiceCloud(localId: localId);
          }
        } catch (e) {
          debugPrint('Sync tombstone failed: ${item.kind} $e');
          return _ExecResult.transientFailure;
        }
        return _ExecResult.success;
      default:
        debugPrint('Sync outbox permanent error: unknown kind "${item.kind}"');
        ref.read(syncFailureMessageProvider.notifier).state =
            'A queued change could not sync (unknown type). See Sync Center.';
        return _ExecResult.permanentFailure;
    }
  }

  Future<int> pendingCount() async {
    await ensureMigrated();
    return _db.countPendingOutbox(ownerUserId: _localOwnerId);
  }

  Future<int> permanentlyFailedCount() async {
    await ensureMigrated();
    final rows = await _db.listActiveOutbox(ownerUserId: _localOwnerId);
    return rows.where((r) => r.status == 'permanently_failed').length;
  }

  Future<List<SyncOutboxEntry>> listVisibleEntries() async {
    await ensureMigrated();
    return _db.listActiveOutbox(ownerUserId: _localOwnerId);
  }

  Future<DateTime?> lastSyncAt() async {
    await ensureMigrated();
    return _db.lastSuccessfulSyncAt(ownerUserId: _localOwnerId);
  }

  /// Clear this user's queue on logout / account switch (keeps other users' rows).
  Future<void> clearForCurrentUser() async {
    await ensureMigrated();
    final id = _localOwnerId;
    if (id != null) {
      await _db.deleteOutboxForUser(id);
      await _db.deleteAllSyncConflicts(ownerUserId: id);
    }
    ref.read(syncFailureMessageProvider.notifier).state = null;
  }
}

enum _ExecResult { success, transientFailure, permanentFailure }

class SyncOutboxItem {
  SyncOutboxItem({
    required this.kind,
    required this.payload,
    this.retries = 0,
    DateTime? createdAt,
    String? operationId,
    this.ownerUserId,
    this.isTombstone = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        operationId = operationId ?? const Uuid().v4();

  final String kind;
  final Map<String, dynamic> payload;
  final int retries;
  final DateTime createdAt;
  final String operationId;
  final int? ownerUserId;
  final bool isTombstone;

  SyncOutboxItem copyWith({int? retries}) => SyncOutboxItem(
        kind: kind,
        payload: payload,
        retries: retries ?? this.retries,
        createdAt: createdAt,
        operationId: operationId,
        ownerUserId: ownerUserId,
        isTombstone: isTombstone,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'payload': payload,
        'retries': retries,
        'createdAt': createdAt.toIso8601String(),
        'operationId': operationId,
        'ownerUserId': ownerUserId,
        'isTombstone': isTombstone,
      };

  factory SyncOutboxItem.fromJson(Map<String, dynamic> json) => SyncOutboxItem(
        kind: json['kind'] as String? ?? '',
        payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
        retries: (json['retries'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        operationId: json['operationId'] as String?,
        ownerUserId: (json['ownerUserId'] as num?)?.toInt(),
        isTombstone: json['isTombstone'] as bool? ?? false,
      );

  factory SyncOutboxItem.fromRow(SyncOutboxEntry row) {
    Map<String, dynamic> payload = {};
    try {
      payload = Map<String, dynamic>.from(jsonDecode(row.payloadJson) as Map);
    } catch (_) {}
    return SyncOutboxItem(
      kind: row.kind,
      payload: payload,
      retries: row.retries,
      createdAt: row.createdAt,
      operationId: row.operationId,
      ownerUserId: row.ownerUserId,
      isTombstone: row.isTombstone,
    );
  }
}

Future<void> showInvoiceConflictDialog(BuildContext context, WidgetRef ref) async {
  await showEntityConflictDialog(context, ref);
}

Future<void> showEntityConflictDialog(BuildContext context, WidgetRef ref) async {
  final outbox = ref.read(syncOutboxServiceProvider);
  final conflicts = await outbox.pendingConflicts();
  if (conflicts.isEmpty || !context.mounted) return;

  for (final c in List<Map<String, dynamic>>.from(conflicts)) {
    if (!context.mounted) return;
    final entityType = (c['entityType'] as String?) ?? 'invoice';
    final localId =
        (c['localId'] as num?)?.toInt() ?? (c['localInvoiceId'] as num?)?.toInt();
    if (localId == null) continue;
    final localStatus = c['localStatus'] as String? ?? '';
    final cloudStatus = c['cloudStatus'] as String? ?? '';
    final shareId = c['shareId'] as String? ?? '';
    final cloudPayloadJson = c['cloudPayloadJson'] as String?;
    final label = entityType == 'project'
        ? 'Project'
        : entityType == 'customer'
            ? 'Client'
            : 'Invoice';

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label sync conflict'),
        content: Text(
          '$label #$localId differs: local is "$localStatus", cloud is "$cloudStatus".\n\n'
          'Keep local uploads your full local record. Take cloud replaces local with cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'local'),
            child: const Text('Keep local'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'cloud'),
            child: const Text('Take cloud'),
          ),
        ],
      ),
    );

    if (choice == null) continue;

    if (entityType == 'invoice') {
      if (choice == 'local') {
        String clientEmail = '';
        String? clientUid;
        try {
          final row = await SupabaseAuthHelper.client
              .from('invoice_shares')
              .select('client_email, client_uid')
              .eq('share_id', shareId)
              .maybeSingle();
          clientEmail = row?['client_email'] as String? ?? '';
          clientUid = row?['client_uid'] as String?;
        } catch (_) {}
        await outbox.resolveConflictKeepLocal(
          localInvoiceId: localId,
          shareId: shareId,
          clientEmail: clientEmail,
          clientUid: clientUid,
        );
      } else if (choice == 'cloud') {
        await outbox.resolveConflictTakeCloud(
          localInvoiceId: localId,
          cloudStatus: cloudStatus,
        );
      }
    } else {
      await outbox.resolveEntityConflict(
        entityType: entityType,
        localId: localId,
        takeCloud: choice == 'cloud',
        cloudStatus: cloudStatus,
        cloudPayloadJson: cloudPayloadJson,
      );
    }
  }

  final remaining = await outbox.pendingConflicts();
  if (remaining.isEmpty) {
    ref.read(syncFailureMessageProvider.notifier).state = null;
  }
}
