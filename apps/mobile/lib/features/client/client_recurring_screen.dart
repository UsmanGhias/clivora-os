import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';

/// Read-only upcoming recurring invoice schedules shared with the client.
class ClientRecurringScreen extends ConsumerWidget {
  const ClientRecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringInvoicesProvider);

    return ClivoraScaffold(
      title: 'Recurring',
      showBackButton: true,
      body: recurringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          final active = items.where((r) => r.isActive).toList();
          if (active.isEmpty) {
            return const EmptyState(
              icon: Icons.autorenew,
              message: 'Upcoming recurring invoices from your freelancer appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: active.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = active[i];
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
                    Text(r.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${r.frequency} · ${formatCurrency(r.total, symbol: currencySymbol(r.currency))}'),
                    Text(
                      'Next: ${DateFormat.yMMMd().format(r.nextRunAt)}',
                      style: const TextStyle(color: ClivoraColors.clientAccent, fontWeight: FontWeight.w600),
                    ),
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
