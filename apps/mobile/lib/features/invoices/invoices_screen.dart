import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/plan_limits.dart';
import '../../core/services/invoice_share_helper.dart';
import '../../core/services/sync_outbox_service.dart';
import '../../core/utils/navigation_helper.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/clivora_bottom_sheet.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/filter_chip_row.dart';
import '../../shared/widgets/stat_summary_card.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key, this.initialFilter});

  final String? initialFilter;

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  late String _status;
  String _sort = 'newest';

  @override
  void initState() {
    super.initState();
    _status = widget.initialFilter ?? 'all';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(syncOutboxServiceProvider).reconcileInvoiceShares();
      if (mounted) await showInvoiceConflictDialog(context, ref);
    });
  }

  @override
  void didUpdateWidget(covariant InvoicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != null && widget.initialFilter != _status) {
      _status = widget.initialFilter!;
    }
  }

  Future<void> _onAddInvoice() async {
    await tryOpenWithPlanCheck(
      context,
      ref: ref,
      canAdd: () => ref.read(planLimitServiceProvider).canAddInvoice(),
      path: '/invoices/new',
      resource: 'invoices this month',
      max: PlanLimits.freeMaxInvoicesPerMonth,
    );
  }

  List<Invoice> _sorted(List<Invoice> invoices) {
    final list = [...invoices];
    switch (_sort) {
      case 'oldest':
        list.sort((a, b) => a.issueDate.compareTo(b.issueDate));
        break;
      case 'amount':
        list.sort((a, b) => b.total.compareTo(a.total));
        break;
      default:
        list.sort((a, b) => b.issueDate.compareTo(a.issueDate));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider(_status == 'all' ? null : _status));
    final statsAsync = ref.watch(invoiceStatsProvider);
    final monthlyCountAsync = ref.watch(monthlyInvoiceCountProvider);
    final customersAsync = ref.watch(customersProvider(null));

    return ClivoraScaffold(
      title: 'Invoices',
      subtitle: 'Manage and track all your invoices',
      showMessagesButton: true,
      action: ClivoraIconButton(icon: Icons.add, onPressed: _onAddInvoice),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          statsAsync.when(
            loading: () => const SizedBox(height: 80),
            error: (_, _) => const SizedBox.shrink(),
            data: (stats) => StatSummaryCard(
              items: [
                StatItem(
                  label: 'Total Invoices',
                  value: '${stats.total}',
                  icon: Icons.description_outlined,
                  iconColor: ClivoraColors.primary,
                ),
                StatItem(
                  label: 'Outstanding Amount',
                  value: formatCurrency(stats.outstanding),
                  valueColor: ClivoraColors.warningOrange,
                  icon: Icons.error_outline,
                  iconColor: ClivoraColors.warningOrange,
                ),
                StatItem(
                  label: 'Paid Amount',
                  value: formatCurrency(stats.paid),
                  valueColor: ClivoraColors.successGreen,
                  icon: Icons.check_circle_outline,
                  iconColor: ClivoraColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilterChipRow(
            options: const ['all', 'draft', 'sent', 'viewed', 'paid'],
            selected: _status,
            onSelected: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              PopupMenuButton<String>(
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'newest', child: Text('Newest')),
                  PopupMenuItem(value: 'oldest', child: Text('Oldest')),
                  PopupMenuItem(value: 'amount', child: Text('Amount')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sort by: ${_sort[0].toUpperCase()}${_sort.substring(1)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.push('/recurring-invoices'),
                icon: const Icon(Icons.autorenew, size: 18, color: ClivoraColors.primary),
                label: const Text(
                  'Recurring Invoices',
                  style: TextStyle(color: ClivoraColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          monthlyCountAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (count) => PlanLimitBanner(
              current: count,
              max: PlanLimits.freeMaxInvoicesPerMonth,
              resource: 'invoices this month',
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: invoicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (invoices) {
                final total = statsAsync.valueOrNull?.total ?? invoices.length;
                final isFiltered = _status != 'all';
                final customerMap = {
                  for (final c in customersAsync.valueOrNull ?? <Customer>[]) c.id: c,
                };
                if (invoices.isEmpty) {
                  if (isFiltered && total > 0) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'No $_status invoices',
                      actionLabel: 'Show all invoices',
                      onAction: () => setState(() => _status = 'all'),
                    );
                  }
                  return ListView(
                    children: [
                      const SizedBox(height: 24),
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        message: 'Create an invoice to request payment, share a PDF, and track what is due.',
                        actionLabel: 'Create invoice',
                        onAction: _onAddInvoice,
                      ),
                      const SizedBox(height: 16),
                      _CreateInvoiceCta(onTap: _onAddInvoice),
                    ],
                  );
                }
                final sorted = _sorted(invoices);
                return ListView.separated(
                  itemCount: sorted.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == sorted.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: _CreateInvoiceCta(onTap: _onAddInvoice),
                      );
                    }
                    final inv = sorted[index];
                    final client = customerMap[inv.customerId];
                    final clientName = client == null
                        ? 'Client'
                        : (client.company.isNotEmpty ? client.company : client.contactPerson);
                    return Dismissible(
                      key: ValueKey(inv.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete invoice?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                ],
                              ),
                            ) ??
                            false;
                      },
                      onDismissed: (_) async {
                        await ref.read(syncOutboxServiceProvider).enqueue(
                              SyncOutboxItem(
                                kind: 'crm_invoice_delete',
                                payload: {'localId': inv.id},
                                isTombstone: true,
                              ),
                            );
                        await ref.read(databaseProvider).deleteInvoice(inv.id);
                      },
                      child: _InvoiceCard(
                        invoice: inv,
                        clientName: clientName,
                        onTap: () => openFormRoute(context, '/invoices/${inv.id}/edit'),
                        onShare: () => shareInvoicePdf(ref, context, inv.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.clientName,
    required this.onTap,
    required this.onShare,
  });

  final Invoice invoice;
  final String clientName;
  final VoidCallback onTap;
  final VoidCallback onShare;

  Color get _statusColor {
    switch (invoice.status) {
      case 'paid':
        return ClivoraColors.successGreen;
      case 'overdue':
        return ClivoraColors.errorRed;
      case 'sent':
        return ClivoraColors.warningOrange;
      case 'viewed':
        return Colors.blue;
      default:
        return ClivoraColors.textSecondary;
    }
  }

  Color get _iconBg {
    switch (invoice.status) {
      case 'paid':
        return ClivoraColors.iconGreen;
      case 'sent':
        return ClivoraColors.iconOrange;
      case 'viewed':
        return ClivoraColors.iconBlue;
      default:
        return ClivoraColors.iconIndigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = invoice.status[0].toUpperCase() + invoice.status.substring(1);
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClivoraColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  invoice.status == 'viewed' ? Icons.visibility_outlined : Icons.receipt_long_outlined,
                  color: _statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      clientName,
                      style: const TextStyle(fontSize: 12, color: ClivoraColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(invoice.total, symbol: currencySymbol(invoice.currency)),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.MMMd().format(invoice.issueDate),
                    style: const TextStyle(fontSize: 11, color: ClivoraColors.textSecondary),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (action) {
                  if (action == 'share') onShare();
                  if (action == 'edit') onTap();
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'share', child: Text('Share PDF')),
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateInvoiceCta extends StatelessWidget {
  const _CreateInvoiceCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ClivoraColors.primaryLight,
            ClivoraColors.primary.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ClivoraColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.post_add_outlined, color: ClivoraColors.primaryDark, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Invoice', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 4),
                Text(
                  'Generate professional invoices and get paid on time.',
                  style: TextStyle(fontSize: 12, color: ClivoraColors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: ClivoraColors.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: const Text('+ New Invoice', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
