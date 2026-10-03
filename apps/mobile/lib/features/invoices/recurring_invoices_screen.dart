import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/services/recurring_invoice_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/models/invoice_line_item.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/form_dialog_fields.dart';

class RecurringInvoicesScreen extends ConsumerWidget {
  const RecurringInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(recurringInvoicesProvider);
    final customersAsync = ref.watch(customersProvider(null));

    return ClivoraScaffold(
      title: 'Recurring invoices',
      showBackButton: true,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Run due now',
            icon: const Icon(Icons.play_circle_outline),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? ClivoraColors.chipBackground
                  : ClivoraColors.darkBorder,
            ),
            onPressed: () async {
              final n = await ref.read(recurringInvoiceServiceProvider).processDue();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(n == 0 ? 'Nothing due' : 'Generated $n invoice(s)')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? ClivoraColors.chipBackground
                  : ClivoraColors.darkBorder,
            ),
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.autorenew,
              message: 'Automate retainers and monthly billing. CLIVORA generates invoices when due.',
              actionLabel: 'New schedule',
              onAction: () => _create(context, ref),
            );
          }
          final customers = {for (final c in customersAsync.valueOrNull ?? []) c.id: c};
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = items[i];
              final client = customers[r.customerId];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? ClivoraColors.darkBorder
                        : ClivoraColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        Switch(
                          value: r.isActive,
                          onChanged: (v) async {
                            await ref.read(databaseProvider).updateRecurringInvoice(
                                  r.copyWith(isActive: v, updatedAt: DateTime.now()),
                                );
                            ref.invalidate(recurringInvoicesProvider);
                          },
                        ),
                        Text(
                          r.isActive ? 'Active' : 'Paused',
                          style: TextStyle(
                            fontSize: 12,
                            color: r.isActive ? ClivoraColors.successGreen : ClivoraColors.warningOrange,
                          ),
                        ),
                      ],
                    ),
                    if (!r.isActive)
                      TextButton.icon(
                        onPressed: () async {
                          await ref.read(databaseProvider).updateRecurringInvoice(
                                r.copyWith(isActive: true, updatedAt: DateTime.now()),
                              );
                          ref.invalidate(recurringInvoicesProvider);
                        },
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Resume'),
                      )
                    else
                      TextButton.icon(
                        onPressed: () async {
                          await ref.read(databaseProvider).updateRecurringInvoice(
                                r.copyWith(isActive: false, updatedAt: DateTime.now()),
                              );
                          ref.invalidate(recurringInvoicesProvider);
                        },
                        icon: const Icon(Icons.pause, size: 18),
                        label: const Text('Pause'),
                      ),
                    Text('${client?.contactPerson ?? 'Client'} · ${r.frequency}'),
                    Text(
                      '${formatCurrency(r.total)} · next ${DateFormat.yMMMd().format(r.nextRunAt)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
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

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final customers = await ref.read(customersProvider(null).future);
    if (customers.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a client first')));
      }
      return;
    }
    var customerId = customers.first.id;
    var frequency = 'monthly';
    final title = TextEditingController(text: 'Monthly retainer');
    final amount = TextEditingController(text: '0');

    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('New recurring invoice'),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: spacedDialogFields([
                    TextField(controller: title, decoration: clivoraDialogFieldDecoration(ctx, 'Title')),
                    DropdownButtonFormField<int>(
                      initialValue: customerId,
                      decoration: clivoraDialogFieldDecoration(ctx, 'Client'),
                      items: customers
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.contactPerson)))
                          .toList(),
                      onChanged: (v) => setLocal(() => customerId = v ?? customerId),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: clivoraDialogFieldDecoration(ctx, 'Frequency'),
                      items: const [
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'biweekly', child: Text('Every 2 weeks')),
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                        DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                      ],
                      onChanged: (v) => setLocal(() => frequency = v ?? frequency),
                    ),
                    TextField(
                      controller: amount,
                      decoration: clivoraDialogFieldDecoration(ctx, 'Amount (USD)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ]),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final unit = double.tryParse(amount.text.trim()) ?? 0;
    final items = [InvoiceLineItem(description: title.text.trim(), quantity: 1, unitPrice: unit)];
    await ref.read(databaseProvider).insertRecurringInvoice(
          RecurringInvoicesCompanion.insert(
            ownerUserId: ownerId,
            title: title.text.trim(),
            customerId: customerId,
            frequency: Value(frequency),
            subtotal: Value(unit),
            total: Value(unit),
            lineItems: Value(encodeLineItems(items)),
            nextRunAt: DateTime.now().add(const Duration(days: 1)),
          ),
        );
    ref.invalidate(recurringInvoicesProvider);
  }
}
