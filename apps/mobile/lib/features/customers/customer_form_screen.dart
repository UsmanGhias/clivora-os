import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/constants/countries.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/crm_refresh.dart';
import '../../core/services/automation_service.dart';
import '../../core/services/client_invite_service.dart';
import '../../core/constants/plan_limits.dart';
import '../../core/utils/form_validators.dart';
import '../../core/utils/plan_limit_dialog.dart';
import '../../core/services/email_verification_service.dart';
import '../../core/services/sync_outbox_service.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/models/invoice_line_item.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/country_picker_field.dart';
import '../../shared/widgets/entity_activity_timeline.dart';
import '../../shared/widgets/step_progress_card.dart';
import 'crm_enrichment_panel.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});

  final int? customerId;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _companyController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalController = TextEditingController();
  final _notesController = TextEditingController();
  String? _country;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _country = kDefaultCountry;
    if (widget.customerId != null) {
      _loadCustomer();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadCustomer() async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final customer = await ref.read(databaseProvider).getCustomerForUser(ownerId, widget.customerId!);
    if (customer != null && mounted) {
      _companyController.text = customer.company;
      _contactController.text = customer.contactPerson;
      final emails = parseStringList(customer.emails);
      final phones = parseStringList(customer.phones);
      _emailController.text = emails.isNotEmpty ? emails.first : '';
      _phoneController.text = phones.isNotEmpty ? phones.first : '';
      _whatsappController.text = customer.whatsapp;
      _addressController.text = customer.address;
      _cityController.text = customer.city;
      _postalController.text = customer.postalCode;
      _country = customer.country.isNotEmpty ? customer.country : kDefaultCountry;
      _notesController.text = customer.notes;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _companyController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final contactErr = FormValidators.requiredField(_contactController.text, field: 'Contact person');
    if (contactErr != null) {
      showFormError(context, contactErr);
      return;
    }
    final email = _emailController.text.trim();
    final emailRequiredErr = FormValidators.requiredField(email, field: 'Email');
    if (emailRequiredErr != null) {
      showFormError(context, emailRequiredErr);
      return;
    }
    final emailErr = FormValidators.email(email);
    if (emailErr != null) {
      showFormError(context, emailErr);
      return;
    }
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      final phoneErr = FormValidators.phone(phone);
      if (phoneErr != null) {
        showFormError(context, phoneErr);
        return;
      }
    }

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final ownerId = ref.read(authStateProvider).valueOrNull!.id;
    final country = (_country ?? kDefaultCountry).trim();
    final emails = encodeStringList(email.isEmpty ? [] : [email]);
    final phones = encodeStringList(phone.isEmpty ? [] : [phone]);

    try {
      if (widget.customerId != null) {
        final existing = await db.getCustomerForUser(ownerId, widget.customerId!);
        if (existing == null) {
          if (mounted) showFormError(context, 'Customer not found');
          return;
        }
        await db.updateCustomer(
          existing.copyWith(
            company: _companyController.text.trim(),
            contactPerson: _contactController.text.trim(),
            emails: emails,
            phones: phones,
            whatsapp: _whatsappController.text.trim(),
            address: _addressController.text.trim(),
            city: _cityController.text.trim(),
            postalCode: _postalController.text.trim(),
            country: country,
            notes: _notesController.text.trim(),
            updatedAt: DateTime.now(),
          ),
        );
        await ref.read(syncOutboxServiceProvider).enqueue(
              SyncOutboxItem(kind: 'crm_customer', payload: {'localId': widget.customerId}),
            );
      } else {
        if (!await requireEmailVerified(context, ref, actionLabel: 'add clients')) {
          return;
        }
        if (!await ref.read(planLimitServiceProvider).canAddCustomer()) {
          if (mounted) {
            final upgrade = await showPlanLimitDialog(
              context,
              resource: 'clients',
              max: PlanLimits.freeMaxClients,
            );
            if (upgrade && mounted) context.push('/upgrade');
          }
          return;
        }
        final id = await db.insertCustomer(
          CustomersCompanion.insert(
            ownerUserId: ownerId,
            contactPerson: _contactController.text.trim(),
            company: Value(_companyController.text.trim()),
            emails: Value(emails),
            phones: Value(phones),
            whatsapp: Value(_whatsappController.text.trim()),
            address: Value(_addressController.text.trim()),
            city: Value(_cityController.text.trim()),
            postalCode: Value(_postalController.text.trim()),
            country: Value(country),
            notes: Value(_notesController.text.trim()),
          ),
        );
        final created = await db.getCustomerForUser(ownerId, id);
        if (created != null) {
          await ref.read(automationServiceProvider).onCustomerCreated(created);
          await ref.read(clientInviteServiceProvider).inviteClient(
                customer: created,
                clientEmail: email,
              );
        }
        await ref.read(syncOutboxServiceProvider).enqueue(
              SyncOutboxItem(kind: 'crm_customer', payload: {'localId': id}),
            );
      }

      if (mounted) {
        invalidateCrmData(ref, customers: true);
        context.pop();
        final email = parseStringList(emails).isNotEmpty ? parseStringList(emails).first : '';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.customerId == null
                    ? '${_contactController.text.trim()} added${email.isNotEmpty ? ' · in-app invite sent to $email' : ''}'
                    : '${_contactController.text.trim()} updated',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) showFormError(context, 'Could not save customer: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                    style: IconButton.styleFrom(
                      backgroundColor: ClivoraColors.chipBackground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.customerId != null ? 'Edit Client' : 'Add Client',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
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
                    title: 'Client Details',
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
                      children: [
                        ClivoraTextField(
                          controller: _companyController,
                          label: 'Business Name',
                          hint: 'Optional',
                          prefixIcon: Icons.business_outlined,
                        ),
                        const SizedBox(height: 16),
                        ClivoraTextField(
                          controller: _contactController,
                          label: 'Contact Person',
                          hint: 'Required',
                          required: true,
                          prefixIcon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),
                        ClivoraTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'Required. Client receives invite',
                          keyboardType: TextInputType.emailAddress,
                          required: true,
                          prefixIcon: Icons.mail_outline,
                        ),
                        const SizedBox(height: 16),
                        ClivoraTextField(
                          controller: _phoneController,
                          label: 'Phone',
                          hint: 'Optional',
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_outlined,
                        ),
                        const SizedBox(height: 16),
                        ClivoraTextField(
                          controller: _whatsappController,
                          label: 'WhatsApp',
                          hint: 'Optional',
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.chat_outlined,
                        ),
                        const SizedBox(height: 16),
                        ClivoraTextField(
                          controller: _addressController,
                          label: 'Address',
                          hint: 'Optional',
                          maxLines: 2,
                          prefixIcon: Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: ClivoraTextField(controller: _cityController, label: 'City', hint: 'Optional')),
                            const SizedBox(width: 12),
                            Expanded(child: ClivoraTextField(controller: _postalController, label: 'Postal', hint: 'Optional')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CountryPickerField(
                          value: _country,
                          onChanged: (v) => setState(() => _country = v),
                        ),
                        const SizedBox(height: 16),
                        ClivoraTextField(
                          controller: _notesController,
                          label: 'Notes',
                          hint: 'Optional',
                          maxLines: 3,
                        ),
                        if (widget.customerId != null) ...[
                          const SizedBox(height: 20),
                          EntityActivityTimeline(
                            entityType: 'customer',
                            entityId: widget.customerId!,
                            title: 'Client activity',
                          ),
                          CrmEnrichmentPanel(localCustomerId: widget.customerId),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.customerId != null ? 'Save Changes' : 'Save Client'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
