import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/supabase_sync_service.dart';
import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';
import 'admin_sync_service.dart';
import 'connectivity_service.dart';
import 'sync_outbox_service.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref);
});

class AnalyticsService {
  AnalyticsService(this.ref);

  final Ref ref;

  Future<void> track({
    required String eventType,
    String? email,
    String? name,
    String plan = 'free',
    double amount = 0,
    String payload = '{}',
  }) async {
    final db = ref.read(databaseProvider);
    await db.insertAnalytics(
      AppAnalyticsCompanion.insert(
        eventType: eventType,
        userEmail: Value(email ?? ''),
        userName: Value(name ?? ''),
        plan: Value(plan),
        amount: Value(amount),
        payload: Value(payload),
      ),
    );
    ref.read(adminSyncServiceProvider).syncPendingEvents();
    final online = await ref.read(connectivityServiceProvider).isOnlineNow();
    if (online) {
      try {
        await ref.read(supabaseSyncServiceProvider).mirrorAnalyticsEvent(
              eventType: eventType,
              userEmail: email ?? '',
              userName: name ?? '',
              plan: plan,
              amount: amount,
              payload: payload,
            );
      } catch (_) {}
    } else {
      await ref.read(syncOutboxServiceProvider).enqueue(
            SyncOutboxItem(
              kind: 'analytics',
              payload: {
                'eventType': eventType,
                'email': email,
                'name': name,
                'plan': plan,
                'amount': amount,
                'payload': payload,
              },
            ),
          );
    }
  }

  Future<void> trackSignup({required String email, required String name}) =>
      track(eventType: 'signup', email: email, name: name);

  Future<void> trackProActivation({required String email, required String name}) =>
      track(
        eventType: 'pro_activate',
        email: email,
        name: name,
        plan: 'pro',
        amount: 0,
      );
}


class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.signups,
    required this.proUsers,
    required this.monthlyRevenue,
  });

  final int totalUsers;
  final int signups;
  final int proUsers;
  final int monthlyRevenue;
}

final analyticsEventsProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).watchAnalytics(limit: 50);
});

final adminUsersProvider = FutureProvider((ref) async {
  return ref.watch(databaseProvider).getAllUsers();
});
