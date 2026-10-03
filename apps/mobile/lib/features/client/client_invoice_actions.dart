import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/cloud/cloud_invoice_repository.dart';
import '../../core/constants/invoice_statuses.dart';
import '../../core/services/client_invoice_helper.dart';
import '../../core/services/dispute_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';

/// Payment confirmation sheet for client invoices.
Future<void> showClientInvoiceActions(
  BuildContext context,
  WidgetRef ref, {
  Invoice? localInvoice,
  CloudInvoiceShare? cloudShare,
}) async {
  final invoice = localInvoice;
  final share = cloudShare;
  final status = share?.status ?? invoice?.status ?? 'draft';
  final canPay = share?.canClientPay ?? (status == 'sent' || status == 'overdue');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              share?.invoiceNumber ?? invoice?.invoiceNumber ?? 'Invoice',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Chip(label: Text(status.replaceAll('_', ' ').toUpperCase())),
            const SizedBox(height: 12),
            Text(
              formatCurrency(
                share?.total ?? invoice?.total ?? 0,
                symbol: currencySymbol(share?.currency ?? invoice?.currency ?? 'USD'),
              ),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            if (share?.paymentMethod.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.payment_outlined),
                title: const Text('Payment method'),
                subtitle: Text(share!.paymentMethod),
              ),
            ],
            if (share?.paymentNote.isNotEmpty == true)
              ListTile(
                leading: const Icon(Icons.note_outlined),
                title: const Text('Payment note'),
                subtitle: Text(share!.paymentNote),
              ),
            if (share?.clientPaidAt != null)
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: ClivoraColors.successGreen),
                title: const Text('Paid on'),
                subtitle: Text(DateFormat.yMMMd().add_jm().format(share!.clientPaidAt!.toLocal())),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                if (invoice != null) {
                  await previewClientInvoice(ref, context, invoice);
                } else if (share != null) {
                  await previewClientInvoiceFromShare(ref, context, share);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invoice PDF not available')),
                  );
                }
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('View branded PDF'),
            ),
            if (status != InvoiceStatuses.disputed &&
                status != InvoiceStatuses.paid &&
                status != InvoiceStatuses.canceled &&
                status != InvoiceStatuses.draft) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final reasonCtrl = TextEditingController();
                  final ok = await showDialog<bool>(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Raise dispute'),
                      content: TextField(
                        controller: reasonCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'What is wrong with this invoice?',
                          hintText: 'Amount, deliverable, or billing issue…',
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Submit')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  final client = ref.read(authStateProvider).valueOrNull;
                  String? err;
                  if (share != null && client != null) {
                    err = await ref.read(disputeServiceProvider).raiseDisputeOnCloudShare(
                          share: share,
                          reason: reasonCtrl.text,
                          raisedByEmail: client.email,
                        );
                  } else if (invoice != null && client != null) {
                    err = await ref.read(disputeServiceProvider).raiseDispute(
                          invoice: invoice,
                          reason: reasonCtrl.text,
                          raisedByEmail: client.email,
                        );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err ?? 'Dispute submitted. Your freelancer was notified.')),
                    );
                  }
                  ref.invalidate(clientCloudInvoicesProvider);
                  ref.invalidate(clientInvoicesProvider);
                },
                icon: const Icon(Icons.gavel_outlined),
                label: const Text('Raise dispute'),
              ),
            ],
            if (canPay) ...[
              const SizedBox(height: 24),
              Text('Confirm payment', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              _PaymentForm(
                onSubmit: (method, note) async {
                  final client = ref.read(authStateProvider).valueOrNull;
                  if (client == null || share == null) return;
                  await ref.read(cloudInvoiceRepositoryProvider).confirmPaymentByClient(
                        share: share,
                        client: client,
                        paymentMethod: method,
                        paymentNote: note,
                      );
                  ref.invalidate(clientCloudInvoicesProvider);
                  ref.invalidate(clientInvoicesProvider);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment submitted. Your freelancer has been notified')),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PaymentForm extends StatefulWidget {
  const _PaymentForm({required this.onSubmit});

  final Future<void> Function(String method, String note) onSubmit;

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  var _method = 'Bank transfer';
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: const InputDecoration(labelText: 'Payment method'),
          items: const [
            DropdownMenuItem(value: 'JazzCash', child: Text('JazzCash')),
            DropdownMenuItem(value: 'EasyPaisa', child: Text('EasyPaisa')),
            DropdownMenuItem(value: 'Bank transfer', child: Text('Bank transfer')),
            DropdownMenuItem(value: 'PayPal', child: Text('PayPal')),
            DropdownMenuItem(value: 'Stripe', child: Text('Stripe / Card')),
            DropdownMenuItem(value: 'Cash', child: Text('Cash')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (v) => setState(() => _method = v ?? _method),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Reference / receipt note',
            hintText: 'Transaction ID, screenshot note, etc. (optional)',
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await widget.onSubmit(_method, _noteCtrl.text.trim());
                  if (mounted) setState(() => _saving = false);
                },
          style: FilledButton.styleFrom(backgroundColor: ClivoraColors.clientAccent),
          child: _saving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Mark as paid'),
        ),
      ],
    );
  }
}
