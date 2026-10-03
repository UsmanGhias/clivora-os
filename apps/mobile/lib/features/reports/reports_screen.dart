import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/crm_report_export_service.dart';
import '../../core/services/payment_allocation_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../core/cloud/cloud_invoice_repository.dart';
import '../../core/auth/auth_service.dart';
import '../../core/services/sync_outbox_service.dart';
import '../../core/services/tracking_service.dart';
import '../../core/auth/user_roles.dart';
import '../../core/constants/plan_features.dart';
import '../../core/utils/navigation_helper.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsProvider);

    return ClivoraScaffold(
      title: 'Reports',
      showBackButton: true,
      action: IconButton(
        tooltip: 'Export report',
        icon: const Icon(Icons.ios_share_outlined),
        onPressed: () async {
          final user = ref.read(authStateProvider).valueOrNull;
          final plan = ref.read(subscriptionPlanProvider).valueOrNull;
          final isClient = isClientUser(user);
          if (!PlanFeatures.dataExport(plan) && !isClient) {
            await requireProFeature(context, isPro: ref.read(isProProvider), featureName: 'Data export');
            return;
          }
          if (isClient && !PlanFeatures.clientDataExport(plan)) {
            await requireProFeature(context, isPro: ref.read(isProProvider), featureName: 'Data export', isClient: true);
            return;
          }
          try {
            await ref.read(crmReportExportServiceProvider).exportAndShare();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
            }
          }
        },
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => ListView(
          children: [
            _SectionTitle(title: 'Financial Overview'),
            _ReportCard(
              title: 'Total Revenue',
              value: formatCurrency(data.revenue),
              subtitle: 'From paid invoices',
              color: ClivoraColors.successGreen,
              icon: Icons.trending_up,
            ),
            _ReportCard(
              title: 'Outstanding',
              value: formatCurrency(data.outstanding),
              subtitle: 'Sent & overdue invoices',
              color: ClivoraColors.warningOrange,
              icon: Icons.pending_outlined,
              onTap: () => context.go('/invoices?filter=outstanding'),
            ),
            _ReportCard(
              title: 'Total Expenses',
              value: formatCurrency(data.totalExpenses),
              subtitle: 'All time',
              color: ClivoraColors.errorRed,
              icon: Icons.receipt_outlined,
              onTap: () => context.push('/expenses'),
            ),
            _ReportCard(
              title: 'Net Profit',
              value: formatCurrency(data.profit),
              subtitle: 'Revenue minus expenses',
              color: ClivoraColors.primaryPurple,
              icon: Icons.account_balance_wallet_outlined,
            ),
            _ReportCard(
              title: 'Tax on paid invoices',
              value: formatCurrency(data.taxCollected),
              subtitle: 'Estimated from line tax rates',
              color: ClivoraColors.primary,
              icon: Icons.percent_outlined,
            ),
            const SizedBox(height: 16),
            _SectionTitle(title: 'Invoice aging'),
            Row(
              children: [
                Expanded(child: _MiniStat(label: 'Current', value: formatCurrency(data.agingCurrent))),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(label: '1-30', value: formatCurrency(data.aging30))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _MiniStat(label: '31-60', value: formatCurrency(data.aging60))),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(label: '60+', value: formatCurrency(data.aging90))),
              ],
            ),

            const SizedBox(height: 16),
            _SectionTitle(title: 'Expenses by category'),
            ..._expenseBreakdown(ref, byCategory: true),
            const SizedBox(height: 16),
            _SectionTitle(title: 'Expenses by vendor'),
            ..._expenseBreakdown(ref, byCategory: false),
            const SizedBox(height: 16),
            _SectionTitle(title: 'This Month'),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Expenses',
                    value: formatCurrency(data.monthlyExpenses),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    label: 'Profit',
                    value: formatCurrency(data.monthlyProfit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionTitle(title: 'Business Summary'),
            Row(
              children: [
                Expanded(child: _MiniStat(label: 'Customers', value: '${data.customers}')),
                const SizedBox(width: 12),
                Expanded(child: _MiniStat(label: 'Projects', value: '${data.projects}')),
                const SizedBox(width: 12),
                Expanded(child: _MiniStat(label: 'Pending Tasks', value: '${data.pendingTasks}')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.bodySmall),
                      Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (onTap != null) const Icon(Icons.chevron_right, color: ClivoraColors.labelGray),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

List<Widget> _expenseBreakdown(WidgetRef ref, {required bool byCategory}) {
  final expenses = ref.watch(expensesProvider(null)).valueOrNull ?? [];
  if (expenses.isEmpty) {
    return [
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('No expenses yet', style: TextStyle(color: ClivoraColors.textSecondary)),
      ),
    ];
  }
  final map = <String, double>{};
  for (final e in expenses) {
    final key = byCategory ? e.category : (e.vendor.isNotEmpty ? e.vendor : 'Unassigned');
    map[key] = (map[key] ?? 0) + e.amount;
  }
  final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in entries.take(8))
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                e.key.isEmpty ? 'Other' : '${e.key[0].toUpperCase()}${e.key.substring(1)}',
              ),
            ),
            Text(formatCurrency(e.value), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
  ];
}

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider('sent'));
    final paidAsync = ref.watch(invoicesProvider('paid'));

    return ClivoraScaffold(
      title: 'Payments',
      showBackButton: true,
      body: ListView(
        children: [
          Text('Pending Payments', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          invoicesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const SizedBox.shrink(),
            data: (invoices) {
              if (invoices.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No pending payments', style: TextStyle(color: ClivoraColors.textSecondary)),
                );
              }
              return Column(
                children: invoices.map((inv) => _PaymentTile(invoice: inv, showMarkPaid: true)).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Recent Payments', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          paidAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (invoices) {
              if (invoices.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No payments recorded yet', style: TextStyle(color: ClivoraColors.textSecondary)),
                );
              }
              return Column(
                children: invoices.take(10).map((inv) => _PaymentTile(invoice: inv)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends ConsumerWidget {
  const _PaymentTile({required this.invoice, this.showMarkPaid = false});

  final Invoice invoice;
  final bool showMarkPaid;

  Future<void> _confirmPaid(BuildContext context, WidgetRef ref) async {
    final remaining = (invoice.total - invoice.amountPaid).clamp(0.0, double.infinity).toDouble();
    final amountCtrl = TextEditingController(text: remaining.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${invoice.invoiceNumber} · balance ${formatCurrency(remaining)}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount received'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save payment')),
        ],
      ),
    );
    if (ok != true) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final amount = double.tryParse(amountCtrl.text.trim()) ?? remaining;
    try {
      await ref.read(paymentAllocationServiceProvider).recordPayment(
            invoiceId: invoice.id,
            amount: amount,
            method: 'manual',
            notes: 'Payment recorded from Hub',
          );
      await ref.read(trackingServiceProvider).logStatusChange(
            entityType: 'invoice',
            entityId: invoice.id,
            status: 'payment',
            note: 'Payment ${formatCurrency(amount)}',
          );
      final updated = await ref.read(databaseProvider).getInvoiceForUser(user.id, invoice.id);
      if (updated != null) {
        final customer = await ref.read(databaseProvider).getCustomerForUser(user.id, invoice.customerId);
        if (customer != null && customer.emails.isNotEmpty) {
          await ref.read(cloudInvoiceRepositoryProvider).syncInvoiceToClient(
                freelancer: user,
                invoice: updated,
                clientEmail: customer.emails.split(',').first.trim(),
              );
        }
      }
      ref.invalidate(invoicesProvider(null));
      ref.invalidate(invoicesProvider('sent'));
      ref.invalidate(invoicesProvider('paid'));
      await ref.read(syncOutboxServiceProvider).reconcileInvoiceShares();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recorded ${formatCurrency(amount)} on ${invoice.invoiceNumber}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: showMarkPaid ? () => _confirmPaid(context, ref) : null,
        tileColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        leading: Icon(
          showMarkPaid ? Icons.pending_outlined : Icons.check_circle,
          color: showMarkPaid ? ClivoraColors.warningOrange : ClivoraColors.successGreen,
        ),
        title: Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          showMarkPaid
              ? 'Balance ${formatCurrency((invoice.total - invoice.amountPaid).clamp(0.0, double.infinity))}'
              : 'Paid ${formatCurrency(invoice.total)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatCurrency(showMarkPaid ? (invoice.total - invoice.amountPaid).clamp(0.0, double.infinity) : invoice.total),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (showMarkPaid) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: ClivoraColors.labelGray.withValues(alpha: 0.8)),
            ],
          ],
        ),
      ),
    );
  }
}
