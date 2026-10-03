import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_service.dart';
import '../constants/plan_features.dart';
import '../constants/plan_limits.dart';
import '../../data/providers/app_providers.dart';

final clientPdfQuotaServiceProvider = Provider<ClientPdfQuotaService>((ref) {
  return ClientPdfQuotaService(ref);
});

/// Tracks monthly client invoice PDF downloads on the free plan.
class ClientPdfQuotaService {
  ClientPdfQuotaService(this.ref);

  final Ref ref;

  String _monthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<String> _prefsKey(int userId) async {
    return 'clivora_client_pdf_count_${userId}_${_monthKey()}';
  }

  Future<int> countThisMonth(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(await _prefsKey(userId)) ?? 0;
  }

  Future<bool> canDownload() async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return false;
    final plan = await ref.read(planLimitServiceProvider).currentPlan();
    if (PlanFeatures.isPro(plan)) return true;
    final count = await countThisMonth(userId);
    return count < PlanLimits.freeMaxClientInvoiceDownloads;
  }

  Future<void> recordDownload() async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;
    final plan = await ref.read(planLimitServiceProvider).currentPlan();
    if (PlanFeatures.isPro(plan)) return;
    final prefs = await SharedPreferences.getInstance();
    final key = await _prefsKey(userId);
    final count = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, count + 1);
  }

  Future<({int used, int limit})> usage() async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return (used: 0, limit: PlanLimits.freeMaxClientInvoiceDownloads);
    final plan = await ref.read(planLimitServiceProvider).currentPlan();
    if (PlanFeatures.isPro(plan)) {
      return (used: 0, limit: PlanLimits.freeMaxClientInvoiceDownloads);
    }
    final used = await countThisMonth(userId);
    return (used: used, limit: PlanLimits.freeMaxClientInvoiceDownloads);
  }
}
