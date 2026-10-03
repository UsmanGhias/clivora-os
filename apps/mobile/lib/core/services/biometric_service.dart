import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/plan_features.dart';
import 'secure_storage_service.dart';
import '../../data/providers/app_providers.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService(ref);
});

/// Biometric unlock (Pro), prompts after configurable idle timeout.
class BiometricService {
  BiometricService(this.ref);

  final Ref ref;
  final _auth = LocalAuthentication();

  static const timeoutOptions = [5, 15, 30, 60];
  static const _timeoutKey = 'clivora_session_timeout_min';
  static const _lastUnlockKey = 'clivora_bio_last_unlock_ms';
  static const _backgroundAtKey = 'clivora_bio_background_at_ms';

  // ignore: unused_field
  bool _sessionUnlocked = false;
  bool _promptInFlight = false;

  Future<int> timeoutMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_timeoutKey) ?? 30;
    return timeoutOptions.contains(v) ? v : 30;
  }

  Future<void> setTimeoutMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final safe = timeoutOptions.contains(minutes) ? minutes : 30;
    await prefs.setInt(_timeoutKey, safe);
  }

  Future<Duration> get lockAfterDuration async =>
      Duration(minutes: await timeoutMinutes());

  Future<bool> get isSupported async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> get isEnabled =>
      ref.read(secureStorageServiceProvider).isBiometricLockEnabled();

  Future<bool> canUseBiometric() async {
    final plan = await ref.read(planLimitServiceProvider).currentPlan();
    return PlanFeatures.biometricLock(plan);
  }

  Future<void> setEnabled(bool value) async {
    await ref.read(secureStorageServiceProvider).setBiometricLock(value);
    if (value) {
      await recordUnlock();
      _sessionUnlocked = true;
    } else {
      _sessionUnlocked = true;
    }
  }

  Future<void> saveAccountEmail(String email) async {
    await ref.read(secureStorageServiceProvider).write(
          SecureStorageService.savedAccountEmailKey,
          email.trim().toLowerCase(),
        );
  }

  Future<String?> savedAccountEmail() =>
      ref.read(secureStorageServiceProvider).read(SecureStorageService.savedAccountEmailKey);

  Future<bool> hasBeenPrompted(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('bio_prompt_$userId') ?? false;
  }

  Future<void> markPrompted(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bio_prompt_$userId', true);
  }

  Future<DateTime?> _lastUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastUnlockKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> recordUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastUnlockKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.remove(_backgroundAtKey);
    _sessionUnlocked = true;
  }

  Future<void> markBackgrounded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_backgroundAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  void markSessionUnlocked() {
    _sessionUnlocked = true;
    recordUnlock();
  }

  /// True when biometric prompt is required (idle or background past timeout).
  Future<bool> shouldPromptUnlock() async {
    if (!await isEnabled) return false;
    if (!await canUseBiometric()) return false;
    if (!await isSupported) return false;

    final lockAfter = await lockAfterDuration;
    final now = DateTime.now();
    final last = await _lastUnlock();
    if (last == null) return true;
    if (now.difference(last) >= lockAfter) return true;

    final prefs = await SharedPreferences.getInstance();
    final bgMs = prefs.getInt(_backgroundAtKey);
    if (bgMs != null) {
      final bg = DateTime.fromMillisecondsSinceEpoch(bgMs);
      if (now.difference(bg) >= lockAfter) return true;
    }
    return false;
  }

  Future<bool> authenticate({String reason = 'Unlock CLIVORA', bool force = false}) async {
    if (!await isEnabled) {
      _sessionUnlocked = true;
      return true;
    }
    if (!await canUseBiometric()) return true;
    if (!await isSupported) return true;
    if (!force && !await shouldPromptUnlock()) return true;
    if (_promptInFlight) return false;

    _promptInFlight = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      if (ok) await recordUnlock();
      return ok;
    } on PlatformException catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    } finally {
      _promptInFlight = false;
    }
  }

  Future<bool> enableForAccount({
    required String email,
    required String displayName,
  }) async {
    if (!await canUseBiometric()) return false;
    if (!await isSupported) return false;
    final ok = await authenticate(
      reason: 'Confirm to save $displayName\'s account',
      force: true,
    );
    if (!ok) return false;
    await saveAccountEmail(email);
    await setEnabled(true);
    return true;
  }
}

List<String> parseSkillsJson(String raw) {
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => '$e'.trim()).where((s) => s.isNotEmpty).toList();
  } catch (_) {
    if (raw.trim().isEmpty) return [];
    return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
}

String skillsToJson(List<String> skills) => jsonEncode(skills);
