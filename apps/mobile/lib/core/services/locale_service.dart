import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeServiceProvider = Provider<LocaleService>((ref) {
  return LocaleService();
});

final appLocaleProvider = StateNotifierProvider<AppLocaleNotifier, Locale?>((ref) {
  return AppLocaleNotifier(ref);
});

/// English / Urdu preference with RTL support via MaterialApp locale.
class LocaleService {
  static const _key = 'clivora_locale_code';

  Future<String> getLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'en';
  }

  Future<void> setLocaleCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}

class AppLocaleNotifier extends StateNotifier<Locale?> {
  AppLocaleNotifier(this.ref) : super(null) {
    _load();
  }

  final Ref ref;

  Future<void> _load() async {
    final code = await ref.read(localeServiceProvider).getLocaleCode();
    if (!mounted) return;
    state = Locale(code);
  }

  Future<void> setLocaleCode(String code) async {
    await ref.read(localeServiceProvider).setLocaleCode(code);
    if (!mounted) return;
    state = Locale(code);
  }
}
