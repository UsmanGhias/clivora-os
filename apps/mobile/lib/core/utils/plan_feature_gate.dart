import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/app_providers.dart';

/// Shows upgrade dialog when a Pro-only feature is tapped on Free plan.
Future<bool> showProFeatureDialog(BuildContext context, {required String featureName}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Pro feature'),
      content: Text('$featureName is available on CLIVORA Pro. Upgrade for unlimited access and advanced tools.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('View Pro'),
        ),
      ],
    ),
  );
  if (result == true && context.mounted) {
    context.push('/upgrade');
  }
  return result ?? false;
}

/// Returns true if user can proceed (Pro or free-allowed).
bool canUsePlanFeature(WidgetRef ref, {required bool freeAllowed}) {
  if (freeAllowed) return true;
  return ref.read(isProProvider);
}

Future<bool> guardProFeature(
  BuildContext context,
  WidgetRef ref, {
  required String featureName,
  required bool freeAllowed,
}) async {
  if (canUsePlanFeature(ref, freeAllowed: freeAllowed)) return true;
  await showProFeatureDialog(context, featureName: featureName);
  return false;
}
