import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_auth_helper.dart';

final cloudAiSuggestionsRepositoryProvider =
    Provider<CloudAiSuggestionsRepository>((ref) {
  return CloudAiSuggestionsRepository();
});

class CloudAiSuggestionsRepository {
  static const _forbidden = {'auto_pay', 'auto_publish'};

  Future<List<Map<String, dynamic>>> listPending() async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return [];
    final rows = await SupabaseAuthHelper.client
        .from('ai_suggestions')
        .select()
        .eq('owner_uid', uid)
        .eq('status', 'pending_review')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> createSample() async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) throw StateError('Not signed in');
    const type = 'summary';
    if (_forbidden.contains(type)) {
      throw StateError('Restricted suggestion types are not allowed');
    }
    final row = await SupabaseAuthHelper.client
        .from('ai_suggestions')
        .insert({
          'owner_uid': uid,
          'entity_type': 'customer',
          'suggestion_type': type,
          'payload': {'summary': 'Sample structured summary for review.'},
          'status': 'pending_review',
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> review(String id, {required bool accept}) async {
    await SupabaseAuthHelper.client.from('ai_suggestions').update({
      'status': accept ? 'accepted' : 'rejected',
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
