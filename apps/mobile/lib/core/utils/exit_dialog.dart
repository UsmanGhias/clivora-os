import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<bool> showExitDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Exit CLIVORA?'),
      content: const Text('Are you sure you want to exit the app?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Exit'),
        ),
      ],
    ),
  );
  if (result == true) {
    SystemNavigator.pop();
  }
  return result ?? false;
}
