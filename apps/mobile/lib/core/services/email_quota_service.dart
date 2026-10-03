import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_service.dart';
import '../constants/plan_features.dart';
import '../../data/providers/app_providers.dart';

final emailQuotaServiceProvider = Provider<EmailQuotaService>((ref) {
  return EmailQuotaService(ref);
});

/// Tracks monthly outbound emails (invites, reminders) per user on free plan.
class EmailQuotaService {
  EmailQuotaService(this.ref);

  final Ref ref;

  String _monthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<String> _prefsKey(int userId) async {
    return 'clivora_email_count_${userId}_${_monthKey()}';
  }

  Future<int> countThisMonth(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(await _prefsKey(userId)) ?? 0;
  }

  Future<int> limitForCurrentUser() async {
    final plan = await ref.read(planLimitServiceProvider).currentPlan();
    return PlanFeatures.emailLimitPerMonth(plan);
  }

  Future<bool> canSendEmail() async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return false;
    final plan = await ref.read(planLimitServiceProvider).currentPlan();
    if (PlanFeatures.isPro(plan)) return true;
    final count = await countThisMonth(userId);
    return count < PlanFeatures.emailLimitPerMonth(plan);
  }

  Future<void> recordSent() async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = await _prefsKey(userId);
    final count = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, count + 1);
  }

  Future<({int used, int limit})> usage() async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return (used: 0, limit: 0);
    final limit = await limitForCurrentUser();
    final used = await countThisMonth(userId);
    return (used: used, limit: limit);
  }
}
