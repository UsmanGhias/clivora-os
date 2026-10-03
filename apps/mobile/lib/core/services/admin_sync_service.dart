import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';
import 'connectivity_service.dart';
import 'sync_outbox_service.dart';

final adminSyncServiceProvider = Provider<AdminSyncService>((ref) {
  return AdminSyncService(ref);
});

/// Pushes analytics events from the app to the clivora-web admin API.
class AdminSyncService {
  AdminSyncService(this.ref);

  final Ref ref;

  Future<void> syncPendingEvents() async {
    final online = await ref.read(connectivityServiceProvider).isOnlineNow();
    if (!online) {
      await ref.read(syncOutboxServiceProvider).enqueue(
            SyncOutboxItem(kind: 'admin_sync', payload: {}),
          );
      return;
    }
    await flushPendingEvents();
  }

  Future<void> flushPendingEvents() async {
    final db = ref.read(databaseProvider);
    final pending = await db.getUnsyncedAnalytics();
    if (pending.isEmpty) return;

    for (final event in pending) {
      final ok = await _postEvent(event);
      if (ok) {
        await db.markAnalyticsSynced(event.id);
      }
    }
  }

  Future<bool> _postEvent(AppAnalytic event) async {
    // Legacy shared-key sync is retired. Events will be sent through the
    // authenticated product-event RPC in the next sync implementation.
    if (kDebugMode) debugPrint('Admin sync deferred: authenticated RPC not configured (${event.id})');
    return false;
  }
}
