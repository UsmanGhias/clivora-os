import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_auth_helper.dart';

final cloudCrmConflictsRepositoryProvider =
    Provider<CloudCrmConflictsRepository>((ref) {
  return CloudCrmConflictsRepository(ref);
});

class CloudCrmConflictsRepository {
  CloudCrmConflictsRepository(this.ref);
  final Ref ref;

  Future<bool> isEnabled() async {
    try {
      for (final key in ['crm_conflict_ui', 'phase4_crm_conflicts']) {
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

  Future<void> reportConflict({
    required String entityType,
    String? entityId,
    int? localId,
    required Map<String, dynamic> localSnapshot,
    required Map<String, dynamic> cloudSnapshot,
  }) async {
    if (!await isEnabled()) return;
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return;
    await SupabaseAuthHelper.client.from('crm_sync_conflicts').insert({
      'owner_uid': uid,
      'entity_type': entityType,
      'entity_id': entityId,
      'local_id': localId,
      'local_snapshot': localSnapshot,
      'cloud_snapshot': cloudSnapshot,
      'status': 'open',
    });
  }

  Future<List<Map<String, dynamic>>> listOpen() async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null || !await isEnabled()) return [];
    final rows = await SupabaseAuthHelper.client
        .from('crm_sync_conflicts')
        .select()
        .eq('owner_uid', uid)
        .eq('status', 'open')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> resolve(String id, {required String resolution}) async {
    await SupabaseAuthHelper.client.from('crm_sync_conflicts').update({
      'status': 'resolved',
      'resolution': resolution,
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
