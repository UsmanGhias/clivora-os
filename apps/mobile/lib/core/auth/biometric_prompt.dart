import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import '../constants/plan_features.dart';
import '../services/biometric_service.dart';
import '../../data/providers/app_providers.dart';

/// Shown once after login for Pro users, save account with biometrics.
Future<void> maybeShowBiometricSavePrompt(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authStateProvider).valueOrNull;
  if (user == null || user.email.isEmpty) return;

  final plan = await ref.read(planLimitServiceProvider).currentPlan();
  if (!PlanFeatures.biometricLock(plan)) return;

  final bio = ref.read(biometricServiceProvider);
  if (await bio.isEnabled) return;
  if (await bio.hasBeenPrompted(user.id)) return;
  if (!await bio.isSupported) {
    await bio.markPrompted(user.id);
    return;
  }

  if (!context.mounted) return;
  final name = user.name.isNotEmpty ? user.name.split(' ').first : 'your';
  final enable = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.fingerprint, size: 40),
      title: const Text('Save this account?'),
      content: Text(
        'Use fingerprint or face to unlock CLIVORA as $name next time.\n\n'
        'Your account (${user.email}) will be saved securely on this device only.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Save my account'),
        ),
      ],
    ),
  );

  await bio.markPrompted(user.id);
  if (enable == true && context.mounted) {
    final ok = await bio.enableForAccount(email: user.email, displayName: name);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Account saved with biometric unlock' : 'Could not enable biometric lock'),
        ),
      );
    }
  }
}
