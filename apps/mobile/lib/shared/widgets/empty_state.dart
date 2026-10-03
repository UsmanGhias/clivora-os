import 'package:flutter/material.dart';

import '../../core/theme/clivora_tokens.dart';
import '../../core/theme/theme_context.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.clivoraColors;
    final layout = context.clivoraLayout;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ClivoraSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: ClivoraSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: ClivoraSpacing.xl),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  backgroundColor: semantic.brand.withValues(alpha: 0.1),
                  foregroundColor: semantic.brand,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ClivoraSpacing.xxl,
                    vertical: ClivoraSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(layout.buttonRadius),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
