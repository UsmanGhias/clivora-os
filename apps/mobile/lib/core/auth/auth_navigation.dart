import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_route_helper.dart';
import 'auth_service.dart';
import 'biometric_prompt.dart';
import '../services/biometric_service.dart';

/// Navigate home after auth, optionally prompt biometric save for Pro users.
Future<void> navigateAfterAuth(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authStateProvider).valueOrNull;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sign-in did not complete. If you used Google, try again or use email sign-in.',
        ),
      ),
    );
    return;
  }
  context.go(homeRouteForUser(user));
  ref.read(biometricServiceProvider).markSessionUnlocked();
  await Future<void>.delayed(const Duration(milliseconds: 400));
  if (context.mounted) {
    await maybeShowBiometricSavePrompt(context, ref);
  }
}

String? authErrorMessage(Object error) {
  final text = error.toString();
  if (text.contains('Null check operator')) {
    return 'Profile data could not be loaded. Try again or use Continue as Guest.';
  }
  if (text.contains('UNIQUE constraint failed')) {
    return 'An account with this email already exists. Try signing in instead.';
  }
  return text.replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
}
