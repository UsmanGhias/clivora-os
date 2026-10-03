import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';

/// Client payments overview, balances and aging from shared invoices.
class ClientPaymentsScreen extends ConsumerWidget {
  const ClientPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(clientInvoicesProvider);

    return ClivoraScaffold(
      title: 'Payments',
      showBackButton: true,
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (invoices) {
          if (invoices.isEmpty) {
            return const EmptyState(
              icon: Icons.payments_outlined,
              message: 'Shared invoices and payment balances appear here.',
            );
          }
          final open = invoices.where((i) => i.status == 'sent' || i.status == 'overdue').toList();
          final paid = invoices.where((i) => i.status == 'paid').toList();
          var current = 0.0, d30 = 0.0, d60 = 0.0, d90 = 0.0;
          final now = DateTime.now();
          for (final inv in open) {
            final bal = (inv.total - inv.amountPaid).clamp(0.0, double.infinity);
            final days = now.difference(inv.dueDate ?? inv.issueDate).inDays;
            if (days <= 0) {
              current += bal;
            } else if (days <= 30) {
              d30 += bal;
            } else if (days <= 60) {
              d60 += bal;
            } else {
              d90 += bal;
            }
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Aging', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _Mini(label: 'Current', value: formatCurrency(current))),
                  const SizedBox(width: 8),
                  Expanded(child: _Mini(label: '1-30', value: formatCurrency(d30))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _Mini(label: '31-60', value: formatCurrency(d60))),
                  const SizedBox(width: 8),
                  Expanded(child: _Mini(label: '60+', value: formatCurrency(d90))),
                ],
              ),
              const SizedBox(height: 20),
              Text('Open balances', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (open.isEmpty)
                const Text('No open balances', style: TextStyle(color: ClivoraColors.textSecondary))
              else
                ...open.map((inv) {
                  final bal = (inv.total - inv.amountPaid).clamp(0.0, double.infinity);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(inv.status),
                    trailing: Text(
                      formatCurrency(bal, symbol: currencySymbol(inv.currency)),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: ClivoraColors.warningOrange),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              Text('Recently paid', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (paid.isEmpty)
                const Text('No payments yet', style: TextStyle(color: ClivoraColors.textSecondary))
              else
                ...paid.take(12).map(
                      (inv) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle, color: ClivoraColors.successGreen),
                        title: Text(inv.invoiceNumber),
                        trailing: Text(formatCurrency(inv.total, symbol: currencySymbol(inv.currency))),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
