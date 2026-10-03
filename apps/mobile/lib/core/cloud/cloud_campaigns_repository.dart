import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_auth_helper.dart';

final cloudCampaignsRepositoryProvider = Provider<CloudCampaignsRepository>((ref) {
  return CloudCampaignsRepository();
});

class CloudCampaignsRepository {
  Future<List<Map<String, dynamic>>> list() async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return [];
    final rows = await SupabaseAuthHelper.client
        .from('campaigns')
        .select()
        .eq('owner_uid', uid)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> createDraft({required String title, String platform = 'connect'}) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) throw StateError('Not signed in');
    final row = await SupabaseAuthHelper.client
        .from('campaigns')
        .insert({
          'owner_uid': uid,
          'title': title.trim(),
          'platform': platform,
          'status': 'draft',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    final id = row['id'] as String;
    await SupabaseAuthHelper.client.from('campaign_blocks').insert({
      'campaign_id': id,
      'block_type': 'text',
      'content': {'text': title.trim()},
      'sort_order': 0,
    });
    return id;
  }

  Future<void> publish(String campaignId) async {
    final blocks = await SupabaseAuthHelper.client
        .from('campaign_blocks')
        .select('id')
        .eq('campaign_id', campaignId);
    final list = blocks as List;
    if (list.isEmpty) {
      await SupabaseAuthHelper.client.from('campaigns').update({
        'status': 'failed',
        'fail_reason': 'At least one block required',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', campaignId);
      throw StateError('At least one block required');
    }
    await SupabaseAuthHelper.client.from('campaigns').update({
      'status': 'published',
      'published_at': DateTime.now().toUtc().toIso8601String(),
      'fail_reason': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', campaignId);
  }
}
