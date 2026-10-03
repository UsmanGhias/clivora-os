import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';

/// Read-only client credit balances issued by freelancers (local when linked).
class ClientCreditsScreen extends ConsumerWidget {
  const ClientCreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(creditsProvider);

    return ClivoraScaffold(
      title: 'Credits',
      showBackButton: true,
      body: creditsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          // Clients typically see credits only when data is synced locally via link.
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              message: 'Credits your freelancer issues will show here with remaining balance.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = items[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.creditNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(c.status),
                    Text(
                      'Balance ${formatCurrency(c.balance)} / ${formatCurrency(c.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: ClivoraColors.clientAccent),
                    ),
                    if (c.notes.isNotEmpty) Text(c.notes, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
