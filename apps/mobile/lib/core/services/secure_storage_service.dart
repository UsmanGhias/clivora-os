import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Encrypted key-value storage for session tokens and sensitive prefs.
class SecureStorageService {
  SecureStorageService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const sessionKey = 'clivora_session_uid';
  static const biometricEnabledKey = 'clivora_biometric_lock';
  static const savedAccountEmailKey = 'clivora_saved_account_email';

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> clearAll() => _storage.deleteAll();

  Future<void> setBiometricLock(bool enabled) =>
      write(biometricEnabledKey, enabled ? '1' : '0');

  Future<bool> isBiometricLockEnabled() async {
    final v = await read(biometricEnabledKey);
    return v == '1';
  }
}
