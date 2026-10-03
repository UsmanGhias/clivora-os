import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/cloud/cloud_quote_repository.dart';
import '../../core/services/invoice_pdf_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';

/// Client-facing quotes shared by freelancers, accept / decline / PDF.
class ClientQuotesScreen extends ConsumerWidget {
  const ClientQuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(clientQuotesProvider);

    return ClivoraScaffold(
      title: 'Quotes',
      showBackButton: true,
      body: quotesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (quotes) {
          if (quotes.isEmpty) {
            return EmptyState(
              icon: Icons.request_quote_outlined,
              message: 'When your freelancer sends a quote, it appears here to accept or decline.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: quotes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final q = quotes[i];
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(q.quoteNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        Chip(
                          label: Text(q.status),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: ClivoraColors.clientSurface,
                          labelStyle: const TextStyle(color: ClivoraColors.clientAccent),
                        ),
                      ],
                    ),
                    Text(formatCurrency(q.total, symbol: currencySymbol(q.currency))),
                    if (q.validUntil != null)
                      Text(
                        'Valid until ${q.validUntil!.toLocal().toString().split(' ').first}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _previewPdf(context, ref, q),
                          child: const Text('View PDF'),
                        ),
                        if (q.status == 'sent') ...[
                          FilledButton.tonal(
                            onPressed: () => _respond(context, ref, q, accept: true),
                            child: const Text('Accept'),
                          ),
                          TextButton(
                            onPressed: () => _respond(context, ref, q, accept: false),
                            child: const Text('Decline'),
                          ),
                        ],
                      ],
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

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    CloudQuoteShare q, {
    required bool accept,
  }) async {
    try {
      await ref.read(cloudQuoteRepositoryProvider).respondToQuote(
            shareId: q.shareId,
            accept: accept,
          );
      ref.invalidate(clientQuotesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accept ? 'Quote accepted' : 'Quote declined')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _previewPdf(BuildContext context, WidgetRef ref, CloudQuoteShare q) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final business = await ref.read(businessProfileProvider.future);
    final branding = await ref.read(invoiceBrandingProvider.future);
    final customer = Customer(
      id: 0,
      ownerUserId: 0,
      contactPerson: user.name,
      company: '',
      emails: '["${user.email}"]',
      phones: '[]',
      whatsapp: '',
      address: '',
      city: '',
      postalCode: '',
      country: '',
      notes: '',
      tags: '[]',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final asInvoice = Invoice(
      id: q.localQuoteId,
      ownerUserId: 0,
      invoiceNumber: q.quoteNumber,
      customerId: 0,
      status: q.status,
      subtotal: q.subtotal,
      taxRate: q.taxRate,
      discount: q.discount,
      total: q.total,
      amountPaid: 0,
      currency: q.currency,
      lineItems: q.lineItems,
      issueDate: q.issueDate ?? DateTime.now(),
      dueDate: q.validUntil,
      createdAt: q.updatedAt ?? DateTime.now(),
      updatedAt: q.updatedAt ?? DateTime.now(),
    );
    try {
      await InvoicePdfService.previewPdf(
        invoice: asInvoice,
        customer: customer,
        business: business,
        branding: branding,
        documentLabel: 'QUOTE',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF: $e')));
      }
    }
  }
}
