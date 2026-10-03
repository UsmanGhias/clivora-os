import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_auth_helper.dart';

final cloudCrmEnrichmentRepositoryProvider = Provider<CloudCrmEnrichmentRepository>((ref) {
  return CloudCrmEnrichmentRepository(ref);
});

/// Cloud sync for Phase 1 CRM enrichment tables (companies, activities, scoring).
/// Gated by app_feature_flags.crm_enrichment - callers should check before heavy use.
class CloudCrmEnrichmentRepository {
  CloudCrmEnrichmentRepository(this.ref);

  final Ref ref;

  Future<bool> isEnrichmentEnabled() async {
    try {
      final row = await SupabaseAuthHelper.client
          .from('app_feature_flags')
          .select('enabled')
          .eq('key', 'crm_enrichment')
          .maybeSingle();
      if (row?['enabled'] == true) return true;
      final row2 = await SupabaseAuthHelper.client
          .from('app_feature_flags')
          .select('enabled')
          .eq('key', 'phase1_crm_enrichment')
          .maybeSingle();
      return row2?['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> listCompanies() async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return [];
    final rows = await SupabaseAuthHelper.client
        .from('crm_companies')
        .select()
        .eq('owner_uid', uid)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> upsertCompany({
    String? id,
    required String name,
    String? website,
    String? industry,
    String notes = '',
  }) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) throw StateError('Not signed in');
    final payload = {
      'owner_uid': uid,
      'name': name.trim(),
      'website': website,
      'industry': industry,
      'notes': notes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id != null) {
      await SupabaseAuthHelper.client.from('crm_companies').update(payload).eq('id', id);
      return id;
    }
    final row = await SupabaseAuthHelper.client
        .from('crm_companies')
        .insert(payload)
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<List<Map<String, dynamic>>> listActivities({String? customerId}) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return [];
    var q = SupabaseAuthHelper.client.from('crm_activities').select().eq('owner_uid', uid);
    if (customerId != null) {
      q = q.eq('customer_id', customerId);
    }
    final rows = await q.order('occurred_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> addActivity({
    String? customerId,
    String? companyId,
    String activityType = 'note',
    required String title,
    String body = '',
  }) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) throw StateError('Not signed in');
    final row = await SupabaseAuthHelper.client
        .from('crm_activities')
        .insert({
          'owner_uid': uid,
          'customer_id': customerId,
          'company_id': companyId,
          'activity_type': activityType,
          'title': title.trim(),
          'body': body,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<int> recomputeLeadScore(String customerId) async {
    final data = await SupabaseAuthHelper.client.rpc(
      'crm_recompute_lead_score',
      params: {'p_customer_id': customerId},
    );
    return (data as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> findDuplicates(String customerId) async {
    final data = await SupabaseAuthHelper.client.rpc(
      'crm_find_duplicate_customers',
      params: {'p_customer_id': customerId},
    );
    return List<Map<String, dynamic>>.from(data as List? ?? const []);
  }

  Future<void> syncPullSafe() async {
    if (!await isEnrichmentEnabled()) return;
    try {
      await listCompanies();
      await listActivities();
    } catch (e) {
      debugPrint('CRM enrichment pull: $e');
    }
  }
}
