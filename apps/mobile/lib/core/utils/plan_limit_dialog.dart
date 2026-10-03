import 'package:flutter/material.dart';

Future<bool> showPlanLimitDialog(
  BuildContext context, {
  required String resource,
  required int max,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Free plan limit reached'),
      content: Text('You can have up to $max $resource on the free plan. Upgrade to Pro for unlimited access.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Upgrade')),
      ],
    ),
  );
  return result ?? false;
}
