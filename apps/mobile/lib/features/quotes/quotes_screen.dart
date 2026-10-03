import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/services/invoice_pdf_service.dart';
import '../../core/cloud/cloud_quote_repository.dart';
import '../../core/cloud/supabase_sync_service.dart';
import '../../core/services/quote_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/models/invoice_line_item.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/form_dialog_fields.dart';

class QuotesScreen extends ConsumerStatefulWidget {
  const QuotesScreen({super.key});

  @override
  ConsumerState<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends ConsumerState<QuotesScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(quotesProvider(_filter == 'all' ? null : _filter));
    final customersAsync = ref.watch(customersProvider(null));

    return ClivoraScaffold(
      title: 'Quotes',
      showBackButton: true,
      action: IconButton(
        icon: const Icon(Icons.add),
        onPressed: () => _createQuote(context),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in const ['all', 'draft', 'sent', 'accepted', 'declined'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f[0].toUpperCase() + f.substring(1)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: quotesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (quotes) {
                if (quotes.isEmpty) {
                  return EmptyState(
                    icon: Icons.request_quote_outlined,
                    message: 'Send priced quotes. Accept and convert to an invoice in one tap.',
                    actionLabel: 'New quote',
                    onAction: () => _createQuote(context),
                  );
                }
                final customers = {for (final c in customersAsync.valueOrNull ?? []) c.id: c};
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: quotes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final q = quotes[i];
                    final client = customers[q.customerId];
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
                                child: Text(q.quoteNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                              Chip(
                                label: Text(q.status),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: ClivoraColors.iconTeal,
                              ),
                            ],
                          ),
                          Text(client?.contactPerson ?? 'Client #${q.customerId}'),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(q.total),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: ClivoraColors.primary),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _shareQuotePdf(q),
                                child: const Text('Share PDF'),
                              ),
                              if (q.status == 'draft' || q.status == 'sent')
                                TextButton(
                                  onPressed: () => _setStatus(q, 'sent'),
                                  child: const Text('Mark sent'),
                                ),
                              if (q.status == 'sent')
                                TextButton(
                                  onPressed: () => _setStatus(q, 'accepted'),
                                  child: const Text('Accept'),
                                ),
                              if (q.status != 'accepted' && q.convertedInvoiceId == null)
                                FilledButton.tonal(
                                  onPressed: () async {
                                    try {
                                      final id = await ref.read(quoteServiceProvider).convertToInvoice(q.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Invoice created (#$id)')),
                                        );
                                        context.push('/invoices/$id/edit');
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                      }
                                    }
                                  },
                                  child: const Text('Convert to invoice'),
                                ),
                              if (q.convertedInvoiceId != null)
                                TextButton(
                                  onPressed: () => context.push('/invoices/${q.convertedInvoiceId}/edit'),
                                  child: const Text('Open invoice'),
                                ),
                            ],
                          ),
                        ],
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

  Future<void> _setStatus(Quote q, String status) async {
    final updated = q.copyWith(status: status, updatedAt: DateTime.now());
    await ref.read(databaseProvider).updateQuote(updated);
    ref.invalidate(quotesProvider);
    if (status == 'sent' || status == 'accepted') {
      await _syncQuoteToClient(updated);
    }
  }

  Future<void> _syncQuoteToClient(Quote q) async {
    try {
      final ownerId = ref.read(authStateProvider).valueOrNull?.id;
      final freelancer = ref.read(authStateProvider).valueOrNull;
      if (ownerId == null || freelancer == null) return;
      final customer = await ref.read(databaseProvider).getCustomerForUser(ownerId, q.customerId);
      if (customer == null) return;
      final emails = parseStringList(customer.emails);
      if (emails.isEmpty) return;
      final clientUid = await ref.read(supabaseSyncServiceProvider).uidForEmail(emails.first);
      await ref.read(cloudQuoteRepositoryProvider).syncQuoteToClient(
            freelancer: freelancer,
            quote: q,
            clientEmail: emails.first,
            clientUid: clientUid,
          );
    } catch (e) {
      // Best-effort cloud sync
    }
  }

  Future<void> _shareQuotePdf(Quote q) async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final db = ref.read(databaseProvider);
    final customer = await db.getCustomerForUser(ownerId, q.customerId);
    if (customer == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client not found')));
      }
      return;
    }
    final business = await ref.read(businessProfileProvider.future);
    final branding = await ref.read(invoiceBrandingProvider.future);
    // Reuse invoice PDF layout with Quote branding via a transient Invoice shape.
    final asInvoice = Invoice(
      id: q.id,
      ownerUserId: q.ownerUserId,
      invoiceNumber: q.quoteNumber,
      customerId: q.customerId,
      projectId: q.projectId,
      status: q.status,
      subtotal: q.subtotal,
      taxRate: q.taxRate,
      discount: q.discount,
      total: q.total,
      amountPaid: 0,
      currency: q.currency,
      lineItems: q.lineItems,
      recurringInvoiceId: null,
      quoteId: q.id,
      issueDate: q.issueDate,
      dueDate: q.validUntil,
      createdAt: q.createdAt,
      updatedAt: q.updatedAt,
    );
    try {
      await InvoicePdfService.sharePdf(
        invoice: asInvoice,
        customer: customer,
        business: business,
        branding: branding,
        documentLabel: 'QUOTE',
      );
      if (q.status == 'draft') {
        await _setStatus(q, 'sent');
      } else {
        await _syncQuoteToClient(q.copyWith(status: 'sent'));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF error: $e')));
      }
    }
  }

  Future<void> _createQuote(BuildContext context) async {
    final customers = await ref.read(customersProvider(null).future);
    if (customers.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a client first')),
        );
      }
      return;
    }
    final products = await ref.read(productsProvider.future);
    var customerId = customers.first.id;
    final desc = TextEditingController(text: products.isNotEmpty ? products.first.name : 'Project work');
    final amount = TextEditingController(
      text: products.isNotEmpty ? products.first.unitPrice.toString() : '0',
    );
    final tax = TextEditingController(text: '0');

    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New quote'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
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
                  if (products.isNotEmpty)
                    DropdownButtonFormField<int>(
                      decoration: clivoraDialogFieldDecoration(ctx, 'From catalog'),
                      items: [
                        const DropdownMenuItem(value: -1, child: Text('Custom line')),
                        ...products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                      ],
                      onChanged: (id) {
                        if (id == null || id < 0) return;
                        final p = products.firstWhere((e) => e.id == id);
                        desc.text = p.name;
                        amount.text = p.unitPrice.toString();
                        tax.text = p.taxRate.toString();
                        setLocal(() {});
                      },
                    ),
                  TextField(controller: desc, decoration: clivoraDialogFieldDecoration(ctx, 'Description')),
                  TextField(
                    controller: amount,
                    decoration: clivoraDialogFieldDecoration(ctx, 'Amount'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: tax,
                    decoration: clivoraDialogFieldDecoration(ctx, 'Tax %'),
                    keyboardType: TextInputType.number,
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final unit = double.tryParse(amount.text.trim()) ?? 0;
    final taxRate = double.tryParse(tax.text.trim()) ?? 0;
    final items = [
      InvoiceLineItem(description: desc.text.trim(), quantity: 1, unitPrice: unit),
    ];
    final subtotal = unit;
    final total = subtotal * (1 + taxRate / 100);
    await ref.read(databaseProvider).insertQuote(
          QuotesCompanion.insert(
            ownerUserId: ownerId,
            quoteNumber: 'Q-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}',
            customerId: customerId,
            status: const Value('draft'),
            subtotal: Value(subtotal),
            taxRate: Value(taxRate),
            total: Value(total),
            lineItems: Value(encodeLineItems(items)),
            validUntil: Value(DateTime.now().add(const Duration(days: 30))),
          ),
        );
    ref.invalidate(quotesProvider);
  }
}
