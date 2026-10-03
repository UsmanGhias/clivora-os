import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final coachMarksServiceProvider = Provider<CoachMarksService>((ref) {
  return CoachMarksService();
});

/// Dashboard tips shown once per account type (freelancer vs client) on this device.
class CoachMarksService {
  static const _enabledKey = 'clivora_coach_marks_enabled';
  static const _freelancerKey = 'clivora_dashboard_coach_done_freelancer';
  static const _clientKey = 'clivora_dashboard_coach_done_client';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  String _keyForRole({required bool isClient}) => isClient ? _clientKey : _freelancerKey;

  Future<bool> isDashboardCompleteForRole({required bool isClient}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyForRole(isClient: isClient)) ?? false;
  }

  Future<void> markDashboardCompleteForRole({required bool isClient}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyForRole(isClient: isClient), true);
  }

  Future<bool> shouldShowForRole({required bool isClient}) async {
    if (!await isEnabled()) return false;
    return !(await isDashboardCompleteForRole(isClient: isClient));
  }
}
