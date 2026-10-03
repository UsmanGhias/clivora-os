import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_auth_helper.dart';

final cloudAutomationRulesRepositoryProvider =
    Provider<CloudAutomationRulesRepository>((ref) {
  return CloudAutomationRulesRepository();
});

class CloudAutomationRulesRepository {
  Future<List<Map<String, dynamic>>> list() async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return [];
    final rows = await SupabaseAuthHelper.client
        .from('automation_rules')
        .select()
        .eq('owner_uid', uid)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> createRule({required String name}) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) throw StateError('Not signed in');
    final row = await SupabaseAuthHelper.client
        .from('automation_rules')
        .insert({
          'owner_uid': uid,
          'name': name.trim(),
          'enabled': false,
          'trigger_type': 'manual',
          'trigger_config': <String, dynamic>{},
          'action_type': 'webhook_queue',
          'action_config': <String, dynamic>{},
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    final id = row['id'] as String;
    await SupabaseAuthHelper.client.from('automation_webhook_queue').insert({
      'owner_uid': uid,
      'event_type': 'automation_rule',
      'status': 'pending',
      'payload': {'rule_id': id, 'note': 'rule_created'},
      'idempotency_key': 'rule-create-$id',
      'next_attempt_at': DateTime.now().toUtc().toIso8601String(),
    });
    return id;
  }
}
