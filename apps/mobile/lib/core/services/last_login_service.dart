import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final lastLoginMethodProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('clivora_last_login_method');
});

/// Remembers the last successful login method for faster sign-in.
class LastLoginService {
  static const _key = 'clivora_last_login_method';

  static Future<void> record(String method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, method);
  }

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }
}

final lastBackupMetaProvider = FutureProvider<({DateTime? at, int? bytes})>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final ms = prefs.getInt('clivora_last_backup_ms');
  final bytes = prefs.getInt('clivora_last_backup_bytes');
  return (at: ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null, bytes: bytes);
});

class BackupMetaService {
  static Future<void> recordExport(int byteLength) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('clivora_last_backup_ms', DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt('clivora_last_backup_bytes', byteLength);
  }
}
