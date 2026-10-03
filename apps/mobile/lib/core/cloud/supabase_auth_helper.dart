import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/admin_config.dart';

/// Primary authentication for CLIVORA. Supabase Auth (email + Google).
class SupabaseAuthHelper {
  static SupabaseClient get client => Supabase.instance.client;

  static String? get currentUid => client.auth.currentUser?.id;

  static String? get currentEmail => client.auth.currentUser?.email;

  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? name,
    String? accountType,
  }) async {
    return client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        if (name != null && name.isNotEmpty) 'name': name,
        if (accountType != null && accountType.isNotEmpty) 'account_type': accountType,
      },
    );
  }

  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  static Future<AuthResponse> signInWithGoogle({
    required String idToken,
    String? accessToken,
  }) async {
    return client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  static Future<void> refreshSessionIfNeeded() async {
    final session = client.auth.currentSession;
    if (session == null) return;
    if (session.isExpired || client.auth.currentUser == null) {
      try {
        await client.auth.refreshSession();
      } catch (e) {
        debugPrint('Supabase session refresh: $e');
      }
    }
  }

  /// Returns true when a usable cloud JWT is present (refreshes if needed).
  static Future<bool> ensureCloudSession() async {
    try {
      var session = client.auth.currentSession;
      if (session == null) return false;
      if (session.isExpired || client.auth.currentUser == null) {
        try {
          await client.auth.refreshSession();
        } catch (e) {
          debugPrint('ensureCloudSession refresh: $e');
        }
      }
      return client.auth.currentUser?.id != null ||
          client.auth.currentSession?.user.id != null;
    } catch (e) {
      debugPrint('ensureCloudSession: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> fetchOwnProfile() async {
    final uid = currentUid;
    if (uid == null) return null;
    try {
      return await client
          .from('profiles')
          .select(
            'id, email, name, avatar_url, account_type, account_type_locked, role, subscription_plan, is_blocked, is_restricted, block_reason, updated_at',
          )
          .eq('id', uid)
          .maybeSingle();
    } catch (e) {
      debugPrint('fetchOwnProfile: $e');
      return null;
    }
  }

  /// Locks freelancer/client role in cloud after first successful auth.
  static Future<void> finalizeAccountType({
    required String accountType,
    String name = '',
  }) async {
    try {
      await client.rpc('finalize_account_type', params: {
        'p_account_type': accountType,
        'p_name': name,
      });
    } catch (e) {
      debugPrint('finalize_account_type RPC: $e, falling back to upsert');
      await upsertProfile(
        email: currentEmail ?? '',
        name: name,
        accountType: accountType,
        role: accountType == 'admin' ? 'admin' : 'user',
        forceLock: true,
      );
    }
  }

  static Future<String?> upsertProfile({
    required String email,
    required String name,
    required String accountType,
    required String role,
    bool forceLock = false,
    String? avatarUrl,
  }) async {
    final uid = currentUid;
    if (uid == null) return null;
    try {
      final existing = await fetchOwnProfile();
      final locked = existing?['account_type_locked'] as bool? ?? false;
      final lockedType = existing?['account_type'] as String?;

      if (locked && lockedType != null && lockedType.isNotEmpty && lockedType != accountType && !forceLock) {
        debugPrint('Profile upsert: type locked as $lockedType');
        return null;
      }

      await client.from('profiles').upsert({
        'id': uid,
        'email': email.trim().toLowerCase(),
        'name': name,
        if (avatarUrl != null && avatarUrl.trim().isNotEmpty) 'avatar_url': avatarUrl.trim(),
        'account_type': accountType,
        'role': role,
        'account_type_locked': forceLock || locked,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return null;
    } catch (e) {
      debugPrint('Supabase profile upsert: $e');
      return '$e';
    }
  }

  /// Upload a local profile image to Storage and return a public URL.
  static Future<String?> uploadAvatarFromPath(String localPath) async {
    final uid = currentUid;
    if (uid == null) return null;
    try {
      final bytes = await File(localPath).readAsBytes();
      final ext = localPath.split('.').last.toLowerCase();
      final safeExt = (ext == 'png' || ext == 'webp' || ext == 'gif') ? ext : 'jpg';
      final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$safeExt';
      for (final bucket in const ['avatars', 'profile-photos']) {
        try {
          await client.storage.from(bucket).uploadBinary(
                path,
                bytes,
                fileOptions: FileOptions(
                  upsert: true,
                  contentType: 'image/$safeExt',
                ),
              );
          final publicUrl = client.storage.from(bucket).getPublicUrl(path);
          if (publicUrl.isNotEmpty) return publicUrl;
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      debugPrint('Avatar upload failed: $e');
    }
    return null;
  }

  static Future<String?> resetPasswordForEmail(String email) async {
    try {
      await client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: kPasswordResetRedirectUrl,
      );
      return null;
    } catch (e) {
      return 'Could not send reset email: $e';
    }
  }

  static Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (_) {}
  }
}
