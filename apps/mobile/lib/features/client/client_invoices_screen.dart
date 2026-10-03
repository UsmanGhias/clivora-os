import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/cloud/cloud_invoice_repository.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import 'client_invoice_actions.dart';

/// Client invoices, cloud sync, PDF view, mark paid with payment method.
class ClientInvoicesScreen extends ConsumerWidget {
  const ClientInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloudAsync = ref.watch(clientCloudInvoicesProvider);
    final localAsync = ref.watch(clientInvoicesProvider);

    return ClivoraScaffold(
      title: 'Invoices',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clientCloudInvoicesProvider);
          ref.invalidate(clientInvoicesProvider);
        },
        child: cloudAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (cloudList) {
            final localList = localAsync.valueOrNull ?? [];
            if (cloudList.isEmpty && localList.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 56, color: ClivoraColors.clientMuted),
                            const SizedBox(height: 16),
                            Text('No invoices yet', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              'When your freelancer sends an invoice, it will appear here with payment details and confirmations.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () => context.push('/client-link-freelancer'),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: const Text('Add your freelancer'),
                              style: FilledButton.styleFrom(
                                backgroundColor: ClivoraColors.clientAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final tiles = cloudList.isNotEmpty
                ? cloudList.map((s) => _CloudInvoiceTile(share: s, localInvoices: localList)).toList()
                : localList
                    .where((i) => i.status != 'draft')
                    .map((i) => _LocalInvoiceTile(invoice: i))
                    .toList();

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: tiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => tiles[i],
            );
          },
        ),
      ),
    );
  }
}

class _CloudInvoiceTile extends ConsumerWidget {
  const _CloudInvoiceTile({required this.share, required this.localInvoices});

  final CloudInvoiceShare share;
  final List<Invoice> localInvoices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Invoice? local;
    for (final inv in localInvoices) {
      if (inv.invoiceNumber == share.invoiceNumber) {
        local = inv;
        break;
      }
    }

    return _InvoiceCard(
      invoiceNumber: share.invoiceNumber,
      status: share.status,
      total: share.total,
      currency: share.currency,
      dueDate: share.dueDate,
      canPay: share.canClientPay,
      onTap: () => showClientInvoiceActions(context, ref, localInvoice: local, cloudShare: share),
    );
  }
}

class _LocalInvoiceTile extends ConsumerWidget {
  const _LocalInvoiceTile({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _InvoiceCard(
      invoiceNumber: invoice.invoiceNumber,
      status: invoice.status,
      total: invoice.total,
      currency: invoice.currency,
      dueDate: invoice.dueDate,
      canPay: invoice.status == 'sent' || invoice.status == 'overdue',
      onTap: () => showClientInvoiceActions(context, ref, localInvoice: invoice),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoiceNumber,
    required this.status,
    required this.total,
    required this.currency,
    required this.onTap,
    this.dueDate,
    this.canPay = false,
  });

  final String invoiceNumber;
  final String status;
  final double total;
  final String currency;
  final DateTime? dueDate;
  final bool canPay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = status == 'paid'
        ? ClivoraColors.successGreen
        : status == 'overdue'
            ? ClivoraColors.errorRed
            : ClivoraColors.clientAccent;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_outlined, color: statusColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                    if (dueDate != null)
                      Text('Due ${DateFormat.yMMMd().format(dueDate!.toLocal())}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatCurrency(total, symbol: currencySymbol(currency)), style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(currency, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    canPay ? 'Tap to pay' : 'View details',
                    style: TextStyle(fontSize: 12, color: canPay ? ClivoraColors.clientAccent : null),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
