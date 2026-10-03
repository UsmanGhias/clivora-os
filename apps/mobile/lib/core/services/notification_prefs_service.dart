import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final notificationPrefsServiceProvider = Provider<NotificationPrefsService>((ref) {
  return NotificationPrefsService();
});

/// Per-category push/local alert toggles (default on).
class NotificationPrefsService {
  static const _messagesKey = 'notif_pref_messages';
  static const _billingKey = 'notif_pref_billing';
  static const _contractsKey = 'notif_pref_contracts';
  static const _teamKey = 'notif_pref_team';

  Future<bool> messagesEnabled() async => _get(_messagesKey);
  Future<bool> billingEnabled() async => _get(_billingKey);
  Future<bool> contractsEnabled() async => _get(_contractsKey);
  Future<bool> teamEnabled() async => _get(_teamKey);

  Future<void> setMessages(bool v) => _set(_messagesKey, v);
  Future<void> setBilling(bool v) => _set(_billingKey, v);
  Future<void> setContracts(bool v) => _set(_contractsKey, v);
  Future<void> setTeam(bool v) => _set(_teamKey, v);

  Future<bool> allowsKind(String kind) async {
    switch (kind) {
      case 'message':
      case 'invite':
        return messagesEnabled();
      case 'invoice':
      case 'quote':
      case 'payment':
        return billingEnabled();
      case 'contract':
        return contractsEnabled();
      case 'team':
      case 'team_invite':
        return teamEnabled();
      default:
        return true;
    }
  }

  Future<bool> _get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  Future<void> _set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
