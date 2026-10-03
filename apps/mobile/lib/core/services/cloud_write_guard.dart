import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';
import 'sync_outbox_service.dart';

final cloudWriteGuardProvider = Provider<CloudWriteGuard>((ref) {
  return CloudWriteGuard(ref);
});

/// Runs a cloud write online, or enqueues it for later when offline.
class CloudWriteGuard {
  CloudWriteGuard(this.ref);

  final Ref ref;

  Future<bool> runOrEnqueue({
    required String kind,
    required Map<String, dynamic> payload,
    required Future<void> Function() action,
  }) async {
    final online = await ref.read(connectivityServiceProvider).isOnlineNow();
    if (!online) {
      await ref.read(syncOutboxServiceProvider).enqueue(
            SyncOutboxItem(kind: kind, payload: payload),
          );
      return false;
    }
    try {
      await action();
      return true;
    } catch (e) {
      debugPrint('Cloud write failed, queuing ($kind): $e');
      await ref.read(syncOutboxServiceProvider).enqueue(
            SyncOutboxItem(kind: kind, payload: payload),
          );
      return false;
    }
  }
}
