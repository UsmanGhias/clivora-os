import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/supabase_auth_helper.dart';

final featureFlagsServiceProvider = Provider<FeatureFlagsService>((ref) {
  return FeatureFlagsService();
});

/// Mirrors web `app_feature_flags` reads (defaults false).
class FeatureFlagsService {
  final Map<String, bool> _cache = {};

  Future<bool> isEnabled(String key) async {
    if (_cache.containsKey(key)) return _cache[key]!;
    try {
      final row = await SupabaseAuthHelper.client
          .from('app_feature_flags')
          .select('enabled')
          .eq('key', key)
          .maybeSingle();
      final on = row?['enabled'] == true;
      _cache[key] = on;
      return on;
    } catch (_) {
      _cache[key] = false;
      return false;
    }
  }

  /// True if any of the keys is enabled (web dual-key pattern).
  Future<bool> anyEnabled(List<String> keys) async {
    for (final k in keys) {
      if (await isEnabled(k)) return true;
    }
    return false;
  }

  Future<bool> crmEnrichment() =>
      anyEnabled(const ['crm_enrichment', 'phase1_crm_enrichment']);

  Future<bool> workspaceTasks() =>
      anyEnabled(const ['workspace_tasks', 'phase2_workspace_tasks']);

  Future<bool> calendarEvents() =>
      anyEnabled(const ['calendar_events', 'phase3_calendar_events']);

  Future<bool> crmConflicts() =>
      anyEnabled(const ['crm_conflict_ui', 'phase4_crm_conflicts']);

  Future<bool> vaultCloud() =>
      anyEnabled(const ['vault_cloud', 'phase5_vault_cloud']);

  Future<bool> campaigns() =>
      anyEnabled(const ['campaigns', 'phase6_campaigns']);

  Future<bool> automationBuilder() =>
      anyEnabled(const ['automation_builder', 'phase7_automation_builder']);

  Future<bool> aiStructured() =>
      anyEnabled(const ['ai_structured', 'phase8_ai_structured']);

  Future<bool> adminOps() =>
      anyEnabled(const ['admin_ops_dashboard', 'phase9_admin_ops']);

  void clearCache() => _cache.clear();
}
