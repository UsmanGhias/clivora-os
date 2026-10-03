import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/invoice_share_helper.dart';
import '../../core/services/invoice_pdf_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants/currencies.dart';
import '../../core/cloud/cloud_invoice_repository.dart';
import '../../core/cloud/supabase_sync_service.dart';
import '../../core/constants/invoice_statuses.dart';
import '../../core/services/audit_log_service.dart';
import '../../core/services/automation_service.dart';
import '../../core/services/tracking_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/models/invoice_line_item.dart';
import '../../core/constants/plan_limits.dart';
import '../../core/utils/crm_refresh.dart';
import '../../core/utils/plan_limit_dialog.dart';
import '../../core/services/email_verification_service.dart';
import '../../core/services/sync_outbox_service.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/step_progress_card.dart';
import '../../shared/widgets/entity_activity_timeline.dart';
import '../../shared/widgets/entity_attachments_panel.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({
    super.key,
    this.invoiceId,
    this.initialLineItems,
    this.initialDescription,
  });

  final int? invoiceId;
  final List<InvoiceLineItem>? initialLineItems;
  final String? initialDescription;

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final _numberController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _taxController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  int? _selectedCustomerId;
  int? _selectedProjectId;
  String _status = 'draft';
  String? _previousStatus;
  String _currency = kDefaultCurrency;
  DateTime? _dueDate;
  bool _loading = true;
  final List<InvoiceLineItem> _lineItems = [];

  @override
  void initState() {
    super.initState();
    for (final c in [_amountController, _taxController, _discountController]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
    if (widget.invoiceId != null) {
      _loadInvoice();
    } else {
      _numberController.text = 'INV-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';
      if (widget.initialLineItems != null && widget.initialLineItems!.isNotEmpty) {
        _lineItems.addAll(widget.initialLineItems!);
        _descriptionController.text = widget.initialDescription ?? widget.initialLineItems!.first.description;
        final total = _lineItems.fold<double>(0, (sum, item) => sum + item.amount);
        _amountController.text = total.toStringAsFixed(2);
      }
      _loading = false;
    }
  }

  Future<void> _loadInvoice() async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final invoice = await ref.read(databaseProvider).getInvoiceForUser(ownerId, widget.invoiceId!);
    if (invoice != null && mounted) {
      _numberController.text = invoice.invoiceNumber;
      _selectedCustomerId = invoice.customerId;
      _selectedProjectId = invoice.projectId;
      _status = invoice.status;
      _previousStatus = invoice.status;
      _currency = invoice.currency.isNotEmpty ? invoice.currency : kDefaultCurrency;
      _taxController.text = invoice.taxRate.toString();
      _discountController.text = invoice.discount.toString();
      _dueDate = invoice.dueDate;
      final items = parseLineItems(invoice.lineItems);
      _lineItems
        ..clear()
        ..addAll(items);
      if (items.isNotEmpty) {
        _descriptionController.text = items.first.description;
        _amountController.text = items.first.unitPrice.toString();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _numberController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _taxController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double _lineSubtotal() {
    if (_lineItems.isNotEmpty) {
      return _lineItems.fold<double>(0, (s, i) => s + i.amount);
    }
    return double.tryParse(_amountController.text.trim()) ?? 0;
  }

  double _calculateTotal() {
    final taxRate = double.tryParse(_taxController.text.trim()) ?? 0;
    final discount = double.tryParse(_discountController.text.trim()) ?? 0;
    final subtotal = _lineSubtotal();
    final tax = subtotal * (taxRate / 100);
    return subtotal + tax - discount;
  }

  void _addLineFromFields() {
    final desc = _descriptionController.text.trim().isEmpty ? 'Service' : _descriptionController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) return;
    setState(() {
      _lineItems.add(InvoiceLineItem(description: desc, quantity: 1, unitPrice: amount));
      _descriptionController.clear();
      _amountController.clear();
    });
  }

  Future<void> _save() async {
    if (_numberController.text.trim().isEmpty || _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice number and customer are required')),
      );
      return;
    }

    // Flush current fields into lines if empty list
    if (_lineItems.isEmpty) {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0;
      _lineItems.add(InvoiceLineItem(
        description: _descriptionController.text.trim().isEmpty ? 'Service' : _descriptionController.text.trim(),
        quantity: 1,
        unitPrice: amount,
      ));
    }
    final taxRate = double.tryParse(_taxController.text.trim()) ?? 0;
    final discount = double.tryParse(_discountController.text.trim()) ?? 0;
    final subtotal = _lineSubtotal();
    final total = _calculateTotal();
    final lineItems = encodeLineItems(List.of(_lineItems));

    final db = ref.read(databaseProvider);
    final ownerId = ref.read(authStateProvider).valueOrNull!.id;
    int? savedId = widget.invoiceId;

    try {
      if (widget.invoiceId != null) {
      final existing = await db.getInvoiceForUser(ownerId, widget.invoiceId!);
      if (existing != null) {
        await db.updateInvoice(
          existing.copyWith(
            invoiceNumber: _numberController.text.trim(),
            customerId: _selectedCustomerId!,
            projectId: Value(_selectedProjectId),
            status: _status,
            currency: _currency,
            subtotal: subtotal,
            taxRate: taxRate,
            discount: discount,
            total: total,
            lineItems: lineItems,
            dueDate: Value(_dueDate),
            updatedAt: DateTime.now(),
          ),
        );
      }
    } else {
      if (!await requireEmailVerified(context, ref, actionLabel: 'add invoices')) {
        return;
      }
      if (!await ref.read(planLimitServiceProvider).canAddInvoice()) {
        if (mounted) {
          final upgrade = await showPlanLimitDialog(
            context,
            resource: 'invoices this month',
            max: PlanLimits.freeMaxInvoicesPerMonth,
          );
          if (upgrade && mounted) context.push('/upgrade');
        }
        return;
      }
      savedId = await db.insertInvoice(
        InvoicesCompanion.insert(
          ownerUserId: ownerId,
          invoiceNumber: _numberController.text.trim(),
          customerId: _selectedCustomerId!,
          projectId: Value(_selectedProjectId),
          status: Value(_status),
          currency: Value(_currency),
          subtotal: Value(subtotal),
          taxRate: Value(taxRate),
          discount: Value(discount),
          total: Value(total),
          lineItems: Value(lineItems),
          dueDate: Value(_dueDate),
        ),
      );
    }

    if (savedId != null && (_previousStatus != _status || widget.invoiceId == null)) {
      await ref.read(trackingServiceProvider).logStatusChange(
            entityType: 'invoice',
            entityId: savedId,
            status: _status,
            note: widget.invoiceId == null ? 'Invoice created' : 'Status updated',
          );
      if (_previousStatus != null && _previousStatus != _status) {
        await ref.read(auditLogServiceProvider).logInvoiceStatusChange(
              invoiceId: savedId,
              fromStatus: _previousStatus!,
              toStatus: _status,
              invoiceNumber: _numberController.text.trim(),
            );
      }
    }

    final savedInvoice = await db.getInvoiceForUser(ownerId, savedId!);
    if (savedInvoice != null) {
      await ref.read(syncOutboxServiceProvider).enqueue(
            SyncOutboxItem(kind: 'crm_invoice', payload: {'localId': savedId}),
          );
      await ref.read(automationServiceProvider).onInvoiceSaved(
            savedInvoice,
            previousStatus: _previousStatus,
          );

      if (savedInvoice.status == 'sent' || savedInvoice.status == 'overdue' || savedInvoice.status == 'paid') {
        try {
          final customer = await db.getCustomerForUser(ownerId, savedInvoice.customerId);
          final emails = customer != null ? parseStringList(customer.emails) : <String>[];
          final freelancer = ref.read(authStateProvider).valueOrNull;
          if (freelancer != null && emails.isNotEmpty) {
            final clientUid = await ref.read(supabaseSyncServiceProvider).uidForEmail(emails.first);
            await ref.read(cloudInvoiceRepositoryProvider).syncInvoiceToClient(
                  freelancer: freelancer,
                  invoice: savedInvoice,
                  clientEmail: emails.first,
                  clientUid: clientUid,
                );
          }
        } catch (e) {
          debugPrint('Invoice cloud sync: $e');
        }
      }
    }

    if (mounted) {
      invalidateCrmData(ref, invoices: true);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(invoiceStatsProvider);
      ref.invalidate(invoicesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _status == 'paid'
                ? 'Invoice saved and counted as revenue'
                : 'Invoice saved. Set status to Paid to track revenue.',
          ),
        ),
      );
      context.pop();
    }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save invoice: $e')),
        );
      }
    }
  }

  Future<void> _exportPdf({bool share = true}) async {
    if (widget.invoiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save the invoice first to export PDF')),
      );
      return;
    }
    if (share) {
      await shareInvoicePdf(ref, context, widget.invoiceId!);
      return;
    }
    final db = ref.read(databaseProvider);
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final invoice = await db.getInvoiceForUser(ownerId, widget.invoiceId!);
    if (_selectedCustomerId == null || invoice == null) return;
    final customer = await db.getCustomerForUser(ownerId, _selectedCustomerId!);
    final business = await ref.read(businessProfileProvider.future);
    final branding = await ref.read(invoiceBrandingProvider.future);
    Project? project;
    if (_selectedProjectId != null) {
      project = await db.getProjectForUser(ownerId, _selectedProjectId!);
    }
    if (customer == null) return;

    try {
      await InvoicePdfService.previewPdf(
        invoice: invoice,
        customer: customer,
        business: business,
        branding: branding,
        project: project,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final customersAsync = ref.watch(customersProvider(null));
    final projectsAsync = ref.watch(projectsProvider(const ProjectFilter()));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                  Text(
                    widget.invoiceId != null ? 'Edit Invoice' : 'New Invoice',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (widget.invoiceId != null) ...[
                    const Spacer(),
                    IconButton(
                      tooltip: 'Preview PDF',
                      onPressed: () => _exportPdf(share: false),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                    IconButton(
                      tooltip: 'Share PDF',
                      onPressed: () => _exportPdf(share: true),
                      icon: const Icon(Icons.share_outlined),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const StepProgressCard(
                    currentStep: 1,
                    totalSteps: 1,
                    title: 'Invoice Details',
                    nextLabel: 'Save',
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClivoraTextField(controller: _numberController, label: 'Invoice Number', required: true),
                        const SizedBox(height: 16),
                        const ClivoraFieldLabel(label: 'Customer', required: true),
                        customersAsync.when(
                          loading: () => const CircularProgressIndicator(),
                          error: (_, _) => const Text('Could not load customers'),
                          data: (customers) {
                            if (customers.isEmpty) {
                              return const Text('Add a customer first');
                            }
                            final unique = {for (final c in customers) c.id: c}.values.toList();
                            final validIds = unique.map((c) => c.id).toSet();
                            final selectedId = _selectedCustomerId != null && validIds.contains(_selectedCustomerId)
                                ? _selectedCustomerId
                                : null;
                            return DropdownButtonFormField<int>(
                              initialValue: selectedId,
                              decoration: const InputDecoration(hintText: 'Select customer'),
                              items: unique
                                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.contactPerson)))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                _selectedCustomerId = v;
                                _selectedProjectId = null;
                              }),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const ClivoraFieldLabel(label: 'Project (optional)'),
                        projectsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (projects) {
                            final filtered = _selectedCustomerId == null
                                ? projects
                                : projects.where((p) => p.customerId == _selectedCustomerId).toList();
                            final validProjectIds = filtered.map((p) => p.id).toSet();
                            final projectId = _selectedProjectId != null && validProjectIds.contains(_selectedProjectId)
                                ? _selectedProjectId
                                : null;
                            return DropdownButtonFormField<int?>(
                              initialValue: projectId,
                              decoration: const InputDecoration(hintText: 'Select project'),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('None')),
                                ...filtered.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                              ],
                              onChanged: (v) async {
                                setState(() => _selectedProjectId = v);
                                if (v == null) return;
                                final ownerId = ref.read(authStateProvider).valueOrNull?.id;
                                if (ownerId == null) return;
                                final project = await ref.read(databaseProvider).getProjectForUser(ownerId, v);
                                if (project == null || !mounted) return;
                                setState(() {
                                  if (project.budget > 0) {
                                    _amountController.text = project.budget.toStringAsFixed(
                                      project.budget == project.budget.roundToDouble() ? 0 : 2,
                                    );
                                  }
                                  if (project.description.isNotEmpty && _descriptionController.text.isEmpty) {
                                    _descriptionController.text = project.description;
                                  }
                                  if (project.currency.isNotEmpty) {
                                    _currency = project.currency;
                                  }
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const ClivoraFieldLabel(label: 'Currency'),
                        DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration: const InputDecoration(hintText: 'Select currency'),
                          items: kSupportedCurrencies
                              .map((c) => DropdownMenuItem(value: c, child: Text('$c (${currencySymbol(c)})')))
                              .toList(),
                          onChanged: (v) => setState(() => _currency = v ?? kDefaultCurrency),
                        ),
                        const SizedBox(height: 16),
                        const ClivoraFieldLabel(label: 'From catalog'),
                        ref.watch(productsProvider).when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (products) {
                            if (products.isEmpty) {
                              return TextButton(
                                onPressed: () => context.push('/products'),
                                child: const Text('Add products to catalog'),
                              );
                            }
                            return DropdownButtonFormField<int>(
                              decoration: const InputDecoration(hintText: 'Pick a product or service'),
                              items: [
                                const DropdownMenuItem(value: -1, child: Text('Custom line')),
                                ...products.map(
                                  (p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text('${p.name} · ${formatCurrency(p.unitPrice)}'),
                                  ),
                                ),
                              ],
                              onChanged: (id) {
                                if (id == null || id < 0) return;
                                final p = products.firstWhere((e) => e.id == id);
                                setState(() {
                                  _descriptionController.text = p.name;
                                  _amountController.text = p.unitPrice.toString();
                                  _taxController.text = p.taxRate.toString();
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_lineItems.isNotEmpty) ...[
                          Text('Line items', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          ..._lineItems.asMap().entries.map((e) {
                            final i = e.key;
                            final item = e.value;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.description),
                              subtitle: Text('Qty ${item.quantity}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(formatCurrency(item.amount)),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () => setState(() => _lineItems.removeAt(i)),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(),
                        ],
                        ClivoraTextField(controller: _descriptionController, label: 'Description', hint: 'Service or item description'),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _addLineFromFields,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add line'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ClivoraTextField(controller: _amountController, label: 'Amount', hint: '0', keyboardType: TextInputType.number, required: true),
                        const SizedBox(height: 16),
                        ClivoraTextField(controller: _taxController, label: 'Tax Rate (%)', keyboardType: TextInputType.number),
                        const SizedBox(height: 16),
                        ClivoraTextField(controller: _discountController, label: 'Discount', keyboardType: TextInputType.number),
                        const SizedBox(height: 16),
                        const ClivoraFieldLabel(label: 'Status'),
                        DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(),
                          items: InvoiceStatuses.all
                              .map((s) => DropdownMenuItem(value: s, child: Text(InvoiceStatuses.label(s))))
                              .toList(),
                          onChanged: (v) => setState(() => _status = v ?? 'draft'),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Due Date'),
                          subtitle: Text(_dueDate != null ? DateFormat.yMMMd().format(_dueDate!) : 'Not set'),
                          trailing: TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) setState(() => _dueDate = picked);
                            },
                            child: const Text('Pick'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total: ${formatCurrency(_calculateTotal(), symbol: currencySymbol(_currency))}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: ClivoraColors.primaryPurple),
                        ),
                      ],
                    ),
                  ),
                  if (widget.invoiceId != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: EntityActivityTimeline(entityType: 'invoice', entityId: widget.invoiceId!),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: EntityAttachmentsPanel(entityType: 'invoice', entityId: widget.invoiceId!),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _save, child: const Text('Save Invoice')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
