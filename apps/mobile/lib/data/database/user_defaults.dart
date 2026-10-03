import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'database.dart';

/// Companions with all NOT NULL columns set, prevents Drift null-read crashes.
extension UserDefaultsHelpers on AppDatabase {
  /// Insert companion with every NOT NULL user column explicitly set.
  UsersCompanion newUserCompanion({
    required String email,
    required String name,
    String passwordHash = '',
    String role = 'user',
    String accountType = 'freelancer',
    String? googleId,
    bool emailVerified = false,
  }) {
    return UsersCompanion.insert(
      email: email.trim().toLowerCase(),
      passwordHash: Value(passwordHash),
      name: name.trim().isNotEmpty ? name.trim() : email.split('@').first,
      role: Value(role),
      accountType: Value(accountType),
      googleId: Value(googleId),
      emailVerified: Value(emailVerified),
      createdAt: Value(DateTime.now()),
    );
  }

  BusinessProfilesCompanion defaultBusinessProfileCompanion(
    int userId, {
    String ownerName = '',
    String email = '',
  }) {
    return BusinessProfilesCompanion(
      userId: Value(userId),
      ownerName: Value(ownerName),
      businessEmail: Value(email),
      businessName: const Value(''),
      businessPhone: const Value(''),
      businessAddress: const Value(''),
      businessCity: const Value(''),
      businessPostalCode: const Value(''),
      businessCountry: const Value(''),
      memberSince: Value(DateTime.now()),
    );
  }

  InvoiceBrandingsCompanion defaultInvoiceBrandingCompanion(int userId) {
    return InvoiceBrandingsCompanion(
      userId: Value(userId),
      accentColor: const Value('#6C63FF'),
      templateStyle: const Value('classic'),
      showLogo: const Value(true),
    );
  }

  AppSettingsTableCompanion defaultAppSettingsCompanion(int userId) {
    return AppSettingsTableCompanion(
      userId: Value(userId),
      themeMode: const Value('light'),
      currency: const Value('USD'),
      timezone: const Value('UTC'),
      subscriptionPlan: const Value('free'),
    );
  }

  DateTime _coerceDateTime(Object? value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is int) {
      if (value > 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true).toLocal();
    }
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  bool _coerceBool(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  /// Read user via raw SQL, never crashes on legacy NULL columns.
  Future<User?> rawReadUserById(int id) async {
    try {
      final row = await customSelect(
        '''
        SELECT id, email, password_hash, name, profile_photo_path, role,
               account_type, google_id, email_verified, created_at
        FROM users WHERE id = ?
        ''',
        variables: [Variable<int>(id)],
        readsFrom: {users},
      ).getSingleOrNull();
      if (row == null) return null;
      final data = row.data;
      return User(
        id: data['id'] as int,
        email: (data['email'] as String?)?.trim().toLowerCase() ?? '',
        passwordHash: (data['password_hash'] as String?) ?? '',
        name: (data['name'] as String?)?.trim().isNotEmpty == true
            ? (data['name'] as String).trim()
            : 'User',
        profilePhotoPath: data['profile_photo_path'] as String?,
        role: (data['role'] as String?)?.isNotEmpty == true ? data['role'] as String : 'user',
        accountType: (data['account_type'] as String?)?.isNotEmpty == true
            ? data['account_type'] as String
            : 'freelancer',
        googleId: data['google_id'] as String?,
        emailVerified: _coerceBool(data['email_verified']),
        createdAt: _coerceDateTime(data['created_at']),
      );
    } catch (e) {
      debugPrint('rawReadUserById($id): $e');
      return null;
    }
  }

  /// Find user id by email without Drift row mapping.
  Future<int?> rawUserIdByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    try {
      final row = await customSelect(
        'SELECT id FROM users WHERE lower(trim(email)) = ? LIMIT 1',
        variables: [Variable<String>(normalized)],
        readsFrom: {users},
      ).getSingleOrNull();
      return row?.read<int>('id');
    } catch (e) {
      debugPrint('rawUserIdByEmail($normalized): $e');
      return null;
    }
  }

  /// Fix NULL columns in [users]. Drift crashes on read when these are null.
  Future<void> repairAllUsersNulls() async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      await customStatement('''
        UPDATE users SET
          password_hash = COALESCE(password_hash, ''),
          name = COALESCE(NULLIF(trim(name), ''), 'User'),
          role = COALESCE(NULLIF(trim(role), ''), 'user'),
          account_type = COALESCE(NULLIF(trim(account_type), ''), 'freelancer'),
          email_verified = COALESCE(email_verified, 0),
          created_at = COALESCE(created_at, $nowSec)
      ''');
      await customStatement(
        "DELETE FROM users WHERE email IS NULL OR trim(email) = ''",
      );
    } catch (e) {
      debugPrint('repairAllUsersNulls: $e');
    }
  }

  /// Fix NULL columns in per-user settings tables (all rows).
  Future<void> repairAllProfileNulls() async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      await customStatement('''
        UPDATE business_profiles SET
          member_since = COALESCE(member_since, $nowSec),
          business_name = COALESCE(business_name, ''),
          business_email = COALESCE(business_email, ''),
          business_phone = COALESCE(business_phone, ''),
          owner_name = COALESCE(owner_name, ''),
          business_address = COALESCE(business_address, ''),
          business_city = COALESCE(business_city, ''),
          business_postal_code = COALESCE(business_postal_code, ''),
          business_country = COALESCE(business_country, '')
      ''');
    } catch (e) {
      debugPrint('repairAllProfileNulls business: $e');
    }
    try {
      await customStatement('''
        UPDATE invoice_brandings SET
          accent_color = COALESCE(accent_color, '#6C63FF'),
          template_style = COALESCE(template_style, 'classic'),
          show_logo = COALESCE(show_logo, 1)
      ''');
    } catch (e) {
      debugPrint('repairAllProfileNulls branding: $e');
    }
    try {
      await customStatement('''
        UPDATE app_settings_table SET
          theme_mode = COALESCE(theme_mode, 'light'),
          currency = COALESCE(currency, 'USD'),
          timezone = COALESCE(timezone, 'UTC'),
          subscription_plan = COALESCE(subscription_plan, 'free')
      ''');
    } catch (e) {
      debugPrint('repairAllProfileNulls settings: $e');
    }
  }

  /// Run all NULL repairs, call before any Drift read on legacy databases.
  Future<void> repairAllDatabaseNulls() async {
    await repairAllUsersNulls();
    await repairAllProfileNulls();
  }

  /// Repair NULL columns before Drift reads (prevents null-check crashes on old DB rows).
  Future<void> repairUserDefaultsNulls(int userId) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      await customStatement('''
        UPDATE users SET
          password_hash = COALESCE(password_hash, ''),
          name = COALESCE(NULLIF(trim(name), ''), 'User'),
          role = COALESCE(NULLIF(trim(role), ''), 'user'),
          account_type = COALESCE(NULLIF(trim(account_type), ''), 'freelancer'),
          email_verified = COALESCE(email_verified, 0),
          created_at = COALESCE(created_at, $nowSec)
        WHERE id = $userId
      ''');
    } catch (e) {
      debugPrint('repairUserDefaultsNulls users: $e');
    }
    try {
      await customStatement('''
        UPDATE business_profiles SET
          member_since = COALESCE(member_since, $nowSec),
          business_name = COALESCE(business_name, ''),
          business_email = COALESCE(business_email, ''),
          business_phone = COALESCE(business_phone, ''),
          owner_name = COALESCE(owner_name, ''),
          business_address = COALESCE(business_address, ''),
          business_city = COALESCE(business_city, ''),
          business_postal_code = COALESCE(business_postal_code, ''),
          business_country = COALESCE(business_country, '')
        WHERE user_id = $userId
      ''');
    } catch (e) {
      debugPrint('repairUserDefaultsNulls business: $e');
    }
    try {
      await customStatement('''
        UPDATE invoice_brandings SET
          accent_color = COALESCE(accent_color, '#6C63FF'),
          template_style = COALESCE(template_style, 'classic'),
          show_logo = COALESCE(show_logo, 1)
        WHERE user_id = $userId
      ''');
    } catch (e) {
      debugPrint('repairUserDefaultsNulls branding: $e');
    }
    try {
      await customStatement('''
        UPDATE app_settings_table SET
          theme_mode = COALESCE(theme_mode, 'light'),
          currency = COALESCE(currency, 'USD'),
          timezone = COALESCE(timezone, 'UTC'),
          subscription_plan = COALESCE(subscription_plan, 'free')
        WHERE user_id = $userId
      ''');
    } catch (e) {
      debugPrint('repairUserDefaultsNulls settings: $e');
    }
  }

  /// Safe per-user defaults, never throws; used during sign-up.
  Future<void> safeSeedUserDefaults(int userId, {String name = '', String email = ''}) async {
    await repairUserDefaultsNulls(userId);
    try {
      await into(businessProfiles).insertOnConflictUpdate(
        defaultBusinessProfileCompanion(userId, ownerName: name, email: email),
      );
    } catch (e) {
      debugPrint('safeSeedUserDefaults business: $e');
    }
    try {
      await into(invoiceBrandings).insertOnConflictUpdate(
        defaultInvoiceBrandingCompanion(userId),
      );
    } catch (e) {
      debugPrint('safeSeedUserDefaults branding: $e');
    }
    try {
      await into(appSettingsTable).insertOnConflictUpdate(
        defaultAppSettingsCompanion(userId),
      );
    } catch (e) {
      debugPrint('safeSeedUserDefaults settings: $e');
    }
    await repairUserDefaultsNulls(userId);
  }

  /// Insert user; recover id if email already exists (corrupt legacy row).
  Future<int> insertUserSafe(UsersCompanion entry) async {
    try {
      final userId = await into(users).insert(entry);
      await repairUserDefaultsNulls(userId);
      return userId;
    } catch (e) {
      final email = entry.email.present ? entry.email.value : null;
      if (email != null) {
        final existingId = await rawUserIdByEmail(email);
        if (existingId != null) {
          await repairUserDefaultsNulls(existingId);
          return existingId;
        }
      }
      rethrow;
    }
  }

  /// Recover a user row that Drift cannot map (NULL columns in legacy DB).
  Future<User?> recoverUserByEmail(String email) async {
    final id = await rawUserIdByEmail(email);
    if (id == null) return null;
    await repairUserDefaultsNulls(id);
    return rawReadUserById(id);
  }

  /// Read user by email, raw SQL first, never throws.
  Future<User?> safeGetUserByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    await repairAllDatabaseNulls();

    final id = await rawUserIdByEmail(normalized);
    if (id == null) return null;

    await repairUserDefaultsNulls(id);
    final raw = await rawReadUserById(id);
    if (raw != null) return raw;

    try {
      return await getUserByEmail(normalized);
    } catch (e) {
      debugPrint('safeGetUserByEmail drift fallback: $e');
      return null;
    }
  }

  /// Read user by id, raw SQL first, never throws.
  Future<User?> safeGetUser(int id) async {
    await repairUserDefaultsNulls(id);
    final raw = await rawReadUserById(id);
    if (raw != null) return raw;

    try {
      return await getUser(id);
    } catch (e) {
      debugPrint('safeGetUser drift fallback: $e');
      return null;
    }
  }
}
