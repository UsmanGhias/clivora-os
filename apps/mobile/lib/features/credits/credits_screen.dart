import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/services/payment_allocation_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/form_dialog_fields.dart';

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(creditsProvider);
    final customersAsync = ref.watch(customersProvider(null));

    return ClivoraScaffold(
      title: 'Credits',
      showBackButton: true,
      action: ClivoraIconButton(icon: Icons.add, onPressed: () => _create(context, ref)),
      body: creditsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              message: 'Issue client credits and apply them to invoices.',
              actionLabel: 'New credit',
              onAction: () => _create(context, ref),
            );
          }
          final customers = {for (final c in customersAsync.valueOrNull ?? []) c.id: c};
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = items[i];
              final client = customers[c.customerId];
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
                    Text(c.creditNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${client?.contactPerson ?? 'Client'} · ${c.status}'),
                    Text(
                      'Balance ${formatCurrency(c.balance)} / ${formatCurrency(c.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: ClivoraColors.primary),
                    ),
                    if (c.balance > 0.001 && c.status == 'open')
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _apply(context, ref, c),
                          child: const Text('Apply to invoice'),
                        ),
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

  Future<void> _apply(BuildContext context, WidgetRef ref, Credit credit) async {
    final invoices = await ref.read(invoicesProvider(null).future);
    final open = invoices
        .where((i) =>
            i.customerId == credit.customerId &&
            i.status != 'paid' &&
            i.status != 'draft' &&
            (i.total - i.amountPaid) > 0.001)
        .toList();
    if (open.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No open invoices for this client')),
        );
      }
      return;
    }
    var invoiceId = open.first.id;
    double remaining() {
      final inv = open.firstWhere((i) => i.id == invoiceId);
      return (inv.total - inv.amountPaid).clamp(0.0, double.infinity).toDouble();
    }
    final amountCtrl = TextEditingController(
      text: credit.balance < remaining() ? credit.balance.toStringAsFixed(2) : remaining().toStringAsFixed(2),
    );
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Apply credit'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: spacedDialogFields([
                DropdownButtonFormField<int>(
                  initialValue: invoiceId,
                  decoration: clivoraDialogFieldDecoration(ctx, 'Invoice'),
                  items: open
                      .map((i) => DropdownMenuItem(
                            value: i.id,
                            child: Text('${i.invoiceNumber} · bal ${formatCurrency(i.total - i.amountPaid)}'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setLocal(() {
                      invoiceId = v;
                      final inv = open.firstWhere((i) => i.id == v);
                      final bal = (inv.total - inv.amountPaid).clamp(0.0, double.infinity).toDouble();
                      final apply = credit.balance < bal ? credit.balance : bal;
                      amountCtrl.text = apply.toStringAsFixed(2);
                    });
                  },
                ),
                TextField(
                  controller: amountCtrl,
                  decoration: clivoraDialogFieldDecoration(
                    ctx,
                    'Amount (max ${formatCurrency(credit.balance)})',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    try {
      await ref.read(paymentAllocationServiceProvider).applyCredit(
            creditId: credit.id,
            invoiceId: invoiceId,
            amount: amount,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Applied ${formatCurrency(amount)}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
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
    final amount = TextEditingController(text: '0');
    final notes = TextEditingController();
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New credit'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: spacedDialogFields([
                DropdownButtonFormField<int>(
                  initialValue: customerId,
                  decoration: clivoraDialogFieldDecoration(ctx, 'Client'),
                  items: customers
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.contactPerson)))
                      .toList(),
                  onChanged: (v) => setLocal(() => customerId = v ?? customerId),
                ),
                TextField(
                  controller: amount,
                  decoration: clivoraDialogFieldDecoration(ctx, 'Amount'),
                  keyboardType: TextInputType.number,
                ),
                TextField(controller: notes, decoration: clivoraDialogFieldDecoration(ctx, 'Notes')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final value = double.tryParse(amount.text.trim()) ?? 0;
    await ref.read(databaseProvider).insertCredit(
          CreditsCompanion.insert(
            ownerUserId: ownerId,
            customerId: customerId,
            creditNumber: 'CR-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}',
            amount: Value(value),
            balance: Value(value),
            notes: Value(notes.text.trim()),
          ),
        );
    ref.invalidate(creditsProvider);
  }
}
