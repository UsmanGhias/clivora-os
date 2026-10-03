import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../data/database/database.dart';
import 'cloud_crm_repository.dart';
import 'supabase_auth_helper.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseAuthHelper.client;
});

final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  return SupabaseSyncService(ref);
});

/// Resolves cross-device links after sign-in.
class SupabaseSyncService {
  SupabaseSyncService(this.ref);

  final Ref ref;

  SupabaseClient get _db => ref.read(supabaseClientProvider);

  Future<void> onUserSignedIn(User user) async {
    final uid = SupabaseAuthHelper.currentUid ?? user.googleId;
    if (uid == null || uid.isEmpty) {
      debugPrint('Supabase sync skipped: no cloud UID for ${user.email}');
      return;
    }
    try {
      await _resolveProjectSharesForClient(uid, user.email);
      await _resolveMessagesForUser(uid, user.email);
      await ref.read(cloudCrmRepositoryProvider).syncAllForSignedInUser();
      subscribeToRealtimeUpdates(uid);
    } catch (e) {
      debugPrint('Supabase user sync error: $e');
    }
  }

  RealtimeChannel? _syncChannel;
  Timer? _syncTimer;

  void subscribeToRealtimeUpdates(String uid) {
    dispose();

    _syncChannel = _db.channel('clivora:sync:$uid');

    void onInsertUpdate(PostgresChangePayload payload) {
      _syncTimer?.cancel();
      _syncTimer = Timer(const Duration(milliseconds: 500), () {
        ref.read(cloudCrmRepositoryProvider).syncAllForSignedInUser();
      });
    }

    void onDelete(PostgresChangePayload payload) {
      debugPrint('Sync: item deleted from ${payload.table}');
    }

    final tables = [
      'crm_customers',
      'crm_projects',
      'crm_invoices',
      'workspace_tasks',
      'notifications'
    ];

    for (final table in tables) {
      _syncChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'owner_uid',
          value: uid,
        ),
        callback: (payload) {
          if (payload.eventType == PostgresChangeEvent.delete) {
            onDelete(payload);
          } else {
            onInsertUpdate(payload);
          }
        },
      );
    }

    _syncChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'to_uid',
        value: uid,
      ),
      callback: (payload) {
        if (payload.eventType == PostgresChangeEvent.delete) {
          onDelete(payload);
        } else {
          onInsertUpdate(payload);
        }
      },
    );

    _syncChannel!.subscribe();
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncChannel?.unsubscribe();
    _syncChannel = null;
  }

  Future<String?> uidForEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    try {
      final viaRpc = await _db.rpc('uid_for_linked_email', params: {'p_email': normalized});
      if (viaRpc != null) return viaRpc as String;
    } catch (e) {
      debugPrint('Supabase uid_for_linked_email: $e');
    }
    try {
      final row = await _db
          .from('profiles')
          .select('id')
          .eq('email', normalized)
          .maybeSingle();
      return row?['id'] as String?;
    } catch (e) {
      debugPrint('Supabase uidForEmail: $e');
      return null;
    }
  }

  Future<void> _resolveProjectSharesForClient(String clientUid, String email) async {
    final normalized = email.trim().toLowerCase();
    try {
      await _db
          .from('project_shares')
          .update({'client_uid': clientUid})
          .eq('client_email', normalized)
          .isFilter('client_uid', null);
    } catch (e) {
      debugPrint('Supabase resolve project shares: $e');
    }
  }

  Future<void> _resolveMessagesForUser(String uid, String email) async {
    final normalized = email.trim().toLowerCase();
    try {
      await _db
          .from('client_messages')
          .update({'to_uid': uid})
          .eq('to_email', normalized)
          .isFilter('to_uid', null);
    } catch (e) {
      debugPrint('Supabase resolve messages: $e');
    }
  }

  Future<void> mirrorAnalyticsEvent({
    required String eventType,
    required String userEmail,
    required String userName,
    required String plan,
    double amount = 0,
    String payload = '{}',
  }) async {
    if (SupabaseAuthHelper.currentUid == null) return;
    try {
      await _db.from('clivora_events').insert({
        'event_type': eventType,
        'user_email': userEmail,
        'user_name': userName,
        'plan': plan,
        'amount': amount,
        'payload': payload,
        'source': 'android',
      });
    } catch (e) {
      debugPrint('Supabase analytics mirror error: $e');
    }
  }
}
