import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../auth/auth_service.dart';
import '../auth/user_roles.dart';
import '../cloud/supabase_auth_helper.dart';
import '../../data/database/database.dart';

final emailVerificationServiceProvider = Provider<EmailVerificationService>((ref) {
  return EmailVerificationService(ref);
});

/// Soft gate: browse OK, create/work actions require verified email.
class EmailVerificationService {
  EmailVerificationService(this.ref);
  final Ref ref;

  /// True when the signed-in user may create CRM work (clients, invoices, etc.).
  bool isVerified(User? user) {
    if (user == null) return false;
    if (isAdminUser(user)) return true;
    if (user.email.toLowerCase().endsWith('@clivora.local')) return true; // guest preview
    if (user.emailVerified) return true;
    final cloud = SupabaseAuthHelper.client.auth.currentUser;
    if (cloud?.emailConfirmedAt != null) return true;
    // Google / OAuth identities are treated as verified.
    final identities = cloud?.identities ?? const [];
    if (identities.any((i) => i.provider == 'google')) return true;
    return false;
  }

  Future<void> syncFromSupabase() async {
    final local = ref.read(authStateProvider).valueOrNull;
    if (local == null) return;
    if (isAdminUser(local) || local.email.toLowerCase().endsWith('@clivora.local')) {
      if (!local.emailVerified) await _setLocalVerified(local, true);
      return;
    }
    try {
      await SupabaseAuthHelper.refreshSessionIfNeeded();
      final cloud = SupabaseAuthHelper.client.auth.currentUser;
      final confirmed = cloud?.emailConfirmedAt != null ||
          (cloud?.identities ?? const []).any((i) => i.provider == 'google');
      if (confirmed && !local.emailVerified) {
        await _setLocalVerified(local, true);
      } else if (!confirmed && local.emailVerified) {
        // Keep local true if already verified offline; don't downgrade.
      }
    } catch (_) {}
  }

  Future<void> _setLocalVerified(User user, bool value) async {
    await ref.read(authStateProvider.notifier).setEmailVerified(value);
  }

  /// Resend Supabase confirmation email (uses the SMTP settings of your Supabase Auth project).
  Future<String?> resendVerificationEmail() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return 'Sign in required';
    if (isVerified(user)) return null;
    final email = user.email.trim().toLowerCase();
    try {
      await SupabaseAuthHelper.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return '$e';
    }
  }
}

/// Blocks create/work actions until email is verified. Returns true if allowed.
Future<bool> requireEmailVerified(
  BuildContext context,
  WidgetRef ref, {
  String actionLabel = 'continue',
}) async {
  final user = ref.read(authStateProvider).valueOrNull;
  final svc = ref.read(emailVerificationServiceProvider);
  await svc.syncFromSupabase();
  final fresh = ref.read(authStateProvider).valueOrNull ?? user;
  if (svc.isVerified(fresh)) return true;

  if (!context.mounted) return false;
  final goProfile = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Verify your email'),
      content: Text(
        'You can browse CLIVORA, but you need to verify $actionLabel.\n\n'
        'Open Profile → Verify email, then check your inbox (and spam).',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Verify now')),
      ],
    ),
  );
  if (goProfile == true && context.mounted) {
    context.push('/profile');
  }
  return false;
}
