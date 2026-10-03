import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService();
});

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  return ref.read(onboardingServiceProvider).isComplete();
});

class OnboardingService {
  static const _key = 'clivora_onboarding_complete_v1';
  static const _guidelinesKey = 'clivora_value_guidelines_seen_v1';

  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<bool> guidelinesSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guidelinesKey) ?? false;
  }

  Future<void> markGuidelinesSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guidelinesKey, true);
  }

  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
