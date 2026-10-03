import 'package:flutter/material.dart';

import '../theme/clivora_colors.dart';
import 'currency_formatter.dart';

/// Polished in-app confirmations for CLIVORA workflows.
class ClivoraUserMessages {
  static void showRoleMismatch(BuildContext context, {required String actualRole}) {
    final workspace = actualRole.toLowerCase() == 'client' ? 'Client Portal' : 'Freelancer Workspace';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.swap_horiz_rounded, color: ClivoraColors.primary, size: 36),
        title: const Text('Account type notice'),
        content: Text(
          'This email is registered as a $actualRole account on CLIVORA.\n\n'
          'We\'ve opened your $workspace so you can continue with the right tools and permissions.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Continue to $workspace'),
          ),
        ],
      ),
    );
  }

  static void showCustomerSaved(
    BuildContext context, {
    required String name,
    required String email,
    required bool isNew,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          isNew ? Icons.person_add_alt_1_rounded : Icons.check_circle_outline,
          color: ClivoraColors.successGreen,
          size: 36,
        ),
        title: Text(isNew ? 'Client added successfully' : 'Client profile updated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isNew
                  ? '$name has been added to your client list.'
                  : 'Changes for $name have been saved.',
            ),
            if (isNew && email.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ClivoraColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Portal invite', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      'An invitation was sent to $email. Once they sign in as a Client, they can view shared projects, invoices, and messages.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  static void showProjectSaved(
    BuildContext context, {
    required String name,
    String currency = 'USD',
    double budget = 0,
    required bool isNew,
  }) {
    final budgetPart = budget > 0
        ? ' · ${formatCurrency(budget, symbol: currencySymbol(currency))}'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isNew
              ? 'Project "$name" created$budgetPart'
              : 'Project "$name" updated$budgetPart',
        ),
      ),
    );
  }
}
