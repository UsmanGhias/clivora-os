import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_auth_helper.dart';

final cloudCalendarEventsRepositoryProvider =
    Provider<CloudCalendarEventsRepository>((ref) {
  return CloudCalendarEventsRepository(ref);
});

class CloudCalendarEventsRepository {
  CloudCalendarEventsRepository(this.ref);
  final Ref ref;

  Future<bool> isEnabled() async {
    try {
      for (final key in ['calendar_events', 'phase3_calendar_events']) {
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

  Future<List<Map<String, dynamic>>> listEvents() async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null || !await isEnabled()) return [];
    final rows = await SupabaseAuthHelper.client
        .from('calendar_events')
        .select()
        .eq('owner_uid', uid)
        .order('starts_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> upsertEvent({
    String? id,
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String description = '',
    String location = '',
    String? projectId,
    String? customerId,
    int? localId,
  }) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) throw StateError('Not signed in');
    final payload = {
      'owner_uid': uid,
      'title': title.trim(),
      'description': description,
      'location': location,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'project_id': projectId,
      'customer_id': customerId,
      'local_id': localId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      if (id != null) {
        await SupabaseAuthHelper.client.from('calendar_events').update(payload).eq('id', id);
        return id;
      }
      final row = await SupabaseAuthHelper.client
          .from('calendar_events')
          .insert(payload)
          .select('id')
          .single();
      return row['id'] as String;
    } catch (e) {
      debugPrint('calendar_events upsert failed: $e');
      rethrow;
    }
  }
}
