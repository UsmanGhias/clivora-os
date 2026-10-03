import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/services/automation_service.dart';
import '../../core/constants/plan_features.dart';
import '../../core/cloud/supabase_auth_helper.dart';
import '../../core/services/contract_pdf_service.dart';
import '../../core/services/vault_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/cloud/cloud_message_repository.dart';
import '../../core/cloud/cloud_notification_repository.dart';
import '../../core/utils/contract_content_helper.dart';
import '../../core/utils/form_validators.dart';
import '../../core/constants/plan_limits.dart';
import '../../core/utils/plan_limit_dialog.dart';
import '../../core/utils/template_utils.dart';
import '../../core/services/email_verification_service.dart';
import '../../data/models/invoice_line_item.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/filter_chip_row.dart';
import '../../shared/widgets/step_progress_card.dart';
import '../../features/client/client_contract_view.dart';

class MessageTemplatesScreen extends ConsumerStatefulWidget {
  const MessageTemplatesScreen({super.key});

  @override
  ConsumerState<MessageTemplatesScreen> createState() => _MessageTemplatesScreenState();
}

class _MessageTemplatesScreenState extends ConsumerState<MessageTemplatesScreen> {
  String _category = 'all';

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(isProProvider);
    final templatesAsync = ref.watch(messageTemplatesProvider(_category == 'all' ? null : _category));

    return ClivoraScaffold(
      title: 'Smart Templates',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTemplateForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New template'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterChipRow(
            options: const ['all', 'invoice', 'project', 'follow-up', 'general'],
            selected: _category,
            onSelected: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 8),
          if (!isPro)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Free plan: up to 3 templates. Pro unlocks unlimited.', style: Theme.of(context).textTheme.bodySmall),
            ),
          Expanded(
            child: templatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading templates: $e')),
              data: (templates) {
                if (templates.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 56, color: ClivoraColors.labelGray.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text('No templates yet', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Create reusable messages with smart variables.', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => _showTemplateForm(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create your first template'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final t = templates[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${t.type.toUpperCase()} · ${t.category}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: ClivoraColors.errorRed),
                          onPressed: () => ref.read(databaseProvider).deleteMessageTemplate(t.id),
                        ),
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

  Future<void> _showTemplateForm(BuildContext context) async {
    if (!await requireEmailVerified(context, ref, actionLabel: 'add templates')) {
      return;
    }
    if (!await ref.read(planLimitServiceProvider).canAddTemplate()) {
      if (context.mounted) {
        final upgrade = await showPlanLimitDialog(
          context,
          resource: 'templates',
          max: PlanLimits.freeMaxTemplates,
        );
        if (upgrade && context.mounted) context.push('/upgrade');
      }
      return;
    }

    final nameCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    const type = 'email';
    var category = 'general';

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setModal) {
            void insertVar(String v) {
              final text = bodyCtrl.text;
              final sel = bodyCtrl.selection;
              final insertAt = sel.start >= 0 ? sel.start : text.length;
              final newText = text.replaceRange(insertAt, sel.end >= 0 ? sel.end : insertAt, v);
              bodyCtrl.text = newText;
              bodyCtrl.selection = TextSelection.collapsed(offset: insertAt + v.length);
            }

            return ClivoraBottomSheetContent(
              title: 'New Template',
              onSave: () async {
                final nameErr = FormValidators.requiredField(nameCtrl.text, field: 'Template name');
                if (nameErr != null) {
                  showFormError(context, nameErr);
                  return;
                }
                final ownerId = ref.read(authStateProvider).valueOrNull?.id;
                if (ownerId == null) return;
                if (!await ref.read(planLimitServiceProvider).canAddTemplate()) {
                  if (context.mounted) {
                    final upgrade = await showPlanLimitDialog(
                      context,
                      resource: 'templates',
                      max: PlanLimits.freeMaxTemplates,
                    );
                    if (upgrade && context.mounted) context.push('/upgrade');
                  }
                  return;
                }
                final db = ref.read(databaseProvider);
                await db.insertMessageTemplate(
                  MessageTemplatesCompanion.insert(
                    ownerUserId: ownerId,
                    name: nameCtrl.text.trim(),
                    type: Value(type),
                    category: Value(category),
                    subject: Value(subjectCtrl.text.trim()),
                    body: Value(bodyCtrl.text.trim()),
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClivoraTextField(controller: nameCtrl, label: 'Template Name', hint: 'e.g. Payment Reminder'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'CATEGORY'),
                    items: const [
                      DropdownMenuItem(value: 'general', child: Text('General')),
                      DropdownMenuItem(value: 'invoice', child: Text('Invoice')),
                      DropdownMenuItem(value: 'project', child: Text('Project')),
                      DropdownMenuItem(value: 'follow-up', child: Text('Follow-up')),
                    ],
                    onChanged: (v) => setModal(() => category = v ?? 'general'),
                  ),
                  const SizedBox(height: 12),
                  ClivoraTextField(controller: subjectCtrl, label: 'Subject', hint: 'Email subject line'),
                  const SizedBox(height: 12),
                  ClivoraTextField(controller: bodyCtrl, label: 'Message Body', hint: 'Write your message…', maxLines: 5),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final v in kTemplateVariableHints)
                        ActionChip(label: Text(v), onPressed: () => insertVar(v)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class ContractsScreen extends ConsumerStatefulWidget {
  const ContractsScreen({super.key});

  @override
  ConsumerState<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends ConsumerState<ContractsScreen> {
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    final contractsAsync = ref.watch(contractsProvider(_status == 'all' ? null : _status));
    return ClivoraScaffold(
      title: 'Contracts',
      showBackButton: true,
      action: ClivoraIconButton(icon: Icons.add, onPressed: () => _createContract(context)),
      body: Column(
        children: [
          FilterChipRow(
            options: const ['all', 'draft', 'sent', 'signed', 'cancelled'],
            selected: _status,
            onSelected: (v) => setState(() => _status = v),
          ),
          Expanded(
            child: contractsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: ClivoraColors.iconPurple,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.description_outlined, size: 36, color: ClivoraColors.primaryPurple),
                          ),
                          const SizedBox(height: 16),
                          Text('No contracts yet', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Create agreements linked to your clients and track signatures.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ClivoraColors.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => _createContract(context),
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Create Contract'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final c = list[i];
                    return Card(
                      child: ListTile(
                        title: Text(c.title),
                        subtitle: Text(c.status.toUpperCase()),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'PDF',
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              onPressed: () => _exportContractPdf(c),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _editContract(context, c),
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

  Future<void> _exportContractPdf(Contract contract) async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final customer = await ref.read(databaseProvider).getCustomerForUser(ownerId, contract.customerId);
    final business = await ref.read(databaseProvider).watchBusinessProfileForUser(ownerId).first;
    if (customer == null || !mounted) return;
    await ContractPdfService.sharePdf(contract: contract, customer: customer, business: business);
  }

  Future<void> _editContract(BuildContext context, Contract contract) async {
    final parsed = ContractContentHelper.decode(contract.content);
    final contentCtrl = TextEditingController(text: parsed.body);
    var status = contract.status;
    var attachmentPath = parsed.attachmentPath;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: Text(contract.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'sent', child: Text('Sent')),
                    DropdownMenuItem(value: 'signed', child: Text('Signed')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (v) => setModal(() => status = v ?? status),
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'Agreement terms'),
                ),
                const SizedBox(height: 12),
                if (attachmentPath != null)
                  ListTile(
                    leading: const Icon(Icons.attach_file),
                    title: Text(attachmentPath!.split(Platform.pathSeparator).last),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setModal(() => attachmentPath = null),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (file != null) setModal(() => attachmentPath = file.path);
                  },
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Attach document'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            if (status == 'draft' || status == 'sent')
              TextButton(
                onPressed: () async {
                  await _shareContractWithClient(ctx, contract, contentCtrl.text.trim(), attachmentPath);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Send to client'),
              ),
            ElevatedButton(
              onPressed: () async {
                final encoded = ContractContentHelper.encode(
                  body: contentCtrl.text.trim(),
                  attachmentPath: attachmentPath,
                  clientSignature: parsed.clientSignature,
                );
                await ref.read(databaseProvider).updateContract(
                      contract.copyWith(
                        content: encoded,
                        status: status,
                        updatedAt: DateTime.now(),
                      ),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareContractWithClient(
    BuildContext context,
    Contract contract,
    String body,
    String? attachmentPath,
  ) async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final customer = await ref.read(databaseProvider).getCustomerForUser(ownerId, contract.customerId);
    if (customer == null) return;
    if (!context.mounted) return;
    final emails = parseStringList(customer.emails);
    if (emails.isEmpty) {
      showFormError(context, 'Add an email to this customer first');
      return;
    }
    final fromUser = ref.read(authStateProvider).valueOrNull;
    if (fromUser == null) return;

    final encoded = ContractContentHelper.encode(body: body, attachmentPath: attachmentPath);
    await ref.read(databaseProvider).updateContract(
          contract.copyWith(content: encoded, status: 'sent', updatedAt: DateTime.now()),
        );
    await ref.read(cloudMessageRepositoryProvider).sendHybrid(
          fromUser: fromUser,
          toEmail: emails.first,
          subject: '${ClientContractView.contractPrefix} ${contract.title}',
          body: encoded,
        );
    await ref.read(cloudNotificationRepositoryProvider).send(
          toEmail: emails.first,
          title: 'Contract ready: ${contract.title}',
          body: 'Review and sign the agreement in your Client Portal.',
          kind: 'contract',
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contract sent to client')),
      );
    }
  }

  Future<void> _createContract(BuildContext context) async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final customers = await ref.read(databaseProvider).watchCustomersForUser(ownerId).first;
    if (!context.mounted) return;
    if (customers.isEmpty) {
      showFormError(context, 'Add a customer first');
      return;
    }
    final titleCtrl = TextEditingController();
    var customerId = customers.first.id;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Contract'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Contract title')),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: customerId,
              items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.contactPerson))).toList(),
              onChanged: (v) => customerId = v ?? customerId,
              decoration: const InputDecoration(labelText: 'Customer'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final ownerId = ref.read(authStateProvider).valueOrNull?.id;
              if (ownerId == null) return;
              await ref.read(databaseProvider).insertContract(
                    ContractsCompanion.insert(
                      ownerUserId: ownerId,
                      customerId: customerId,
                      title: titleCtrl.text.trim(),
                      content: Value('Agreement terms to be defined.'),
                    ),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class AutomationsScreen extends ConsumerWidget {
  const AutomationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(automationSettingsProvider);
    final runsAsync = ref.watch(_automationRunsProvider);
    final pipelines = <({String trigger, String action})>[
      if (settings.overdueFollowUp)
        (trigger: 'Invoice overdue', action: 'Create task + notify'),
      if (settings.customerWelcome)
        (trigger: 'New customer', action: 'Welcome note + onboarding task'),
      if (settings.weeklySummary)
        (trigger: 'Every 7 days', action: 'Revenue summary note'),
      if (settings.taskAssignedMessage)
        (trigger: 'Task assigned', action: 'Send client message'),
      if (settings.contractSignedStage)
        (trigger: 'Contract signed', action: 'Project → in progress'),
      if (settings.inactiveClientReminder)
        (trigger: 'Client inactive 7+ days', action: 'Create follow-up task'),
    ];
    return ClivoraScaffold(
      title: 'Workflows',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Automations run on your device when you save customers or invoices.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text('Active pipeline', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (pipelines.isEmpty)
            Text(
              'Enable a toggle below to build your workflow pipeline.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...pipelines.map(
              (p) => _PipelineCard(trigger: p.trigger, action: p.action),
            ),
          const SizedBox(height: 20),
          Text('Automations', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _AutomationTile(
            title: 'Overdue invoice follow-up',
            subtitle: 'Creates a high-priority task when an invoice is marked overdue',
            enabled: settings.overdueFollowUp,
            onChanged: ref.read(automationSettingsProvider.notifier).setOverdueFollowUp,
          ),
          _AutomationTile(
            title: 'New customer welcome',
            subtitle: 'Adds a welcome note and onboarding task for new clients',
            enabled: settings.customerWelcome,
            onChanged: ref.read(automationSettingsProvider.notifier).setCustomerWelcome,
          ),
          _AutomationTile(
            title: 'Weekly revenue summary',
            subtitle: 'Creates a weekly revenue note every 7 days when enabled',
            enabled: settings.weeklySummary,
            onChanged: ref.read(automationSettingsProvider.notifier).setWeeklySummary,
          ),
          _AutomationTile(
            title: 'Task assigned message',
            subtitle: 'Sends a message when a task is assigned to a client',
            enabled: settings.taskAssignedMessage,
            onChanged: ref.read(automationSettingsProvider.notifier).setTaskAssignedMessage,
          ),
          _AutomationTile(
            title: 'Contract signed stage change',
            subtitle: 'Moves linked project to in progress when contract is signed',
            enabled: settings.contractSignedStage,
            onChanged: ref.read(automationSettingsProvider.notifier).setContractSignedStage,
          ),
          _AutomationTile(
            title: 'Inactive client reminder',
            subtitle: 'Creates follow-up tasks for clients inactive 7+ days',
            enabled: settings.inactiveClientReminder,
            onChanged: ref.read(automationSettingsProvider.notifier).setInactiveClientReminder,
          ),
          const SizedBox(height: 24),
          Text('Recent runs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          runsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Text('Could not load run log'),
            data: (runs) {
              if (runs.isEmpty) {
                return Text('No runs logged yet.', style: Theme.of(context).textTheme.bodySmall);
              }
              return Column(
                children: [
                  for (final run in runs)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${run['key'] ?? 'run'}'),
                      subtitle: Text('${run['detail'] ?? ''}'),
                      trailing: Text(
                        '${run['created_at'] ?? ''}'.length >= 10
                            ? '${run['created_at']}'.substring(0, 10)
                            : '${run['created_at'] ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

final _automationRunsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  if (SupabaseAuthHelper.currentUid == null) return Future.value([]);
  return ref.read(automationServiceProvider).recentRuns(limit: 20);
});

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.trigger, required this.action});

  final String trigger;
  final String action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Flexible(
            child: _PipelineChip(
              label: trigger,
              background: scheme.primaryContainer.withValues(alpha: 0.55),
              foreground: scheme.onPrimaryContainer,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.outline),
          ),
          Flexible(
            child: _PipelineChip(
              label: action,
              background: scheme.secondaryContainer.withValues(alpha: 0.55),
              foreground: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineChip extends StatelessWidget {
  const _PipelineChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _AutomationTile extends StatelessWidget {
  const _AutomationTile({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(vaultFilesProvider);
    final planAsync = ref.watch(vaultPlanProvider);

    return planAsync.when(
      loading: () => const ClivoraScaffold(
        title: 'File Vault',
        showBackButton: true,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ClivoraScaffold(title: 'File Vault', showBackButton: true, body: Center(child: Text('$e'))),
      data: (plan) {
        final limit = VaultService.limitBytesForPlan(plan);
        final isPro = PlanFeatures.isPro(plan);
        return ClivoraScaffold(
          title: 'File Vault',
          showBackButton: true,
          action: isPro
              ? ClivoraIconButton(
                  icon: Icons.add,
                  onPressed: () async {
                    final result = await VaultService.pickAndSave(plan: plan);
                    if (!context.mounted) return;
                    if (result.isQuota) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Vault full. Upgrade to Pro for 5 GB storage.')),
                      );
                    } else if (result.ok) {
                      ref.invalidate(vaultFilesProvider);
                    }
                  },
                )
              : null,
          body: filesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (files) {
              final total = VaultService.totalBytes(files);
              final chatCount = files.where((f) => VaultService.isChatArchive(f.path)).length;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
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
                        Text(
                          '${VaultService.formatSize(total)} of ${VaultService.formatSize(limit)} used',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: limit > 0 ? (total / limit).clamp(0.0, 1.0) : 0,
                            minHeight: 8,
                            backgroundColor: ClivoraColors.labelGray.withValues(alpha: 0.15),
                            color: total > limit * 0.9 ? ClivoraColors.warningOrange : ClivoraColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${files.length} file${files.length == 1 ? '' : 's'} · $chatCount from chat (locked)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (!isPro) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Free plan includes 100 MB. Chat images are saved automatically. Pro unlocks 5 GB and manual uploads.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ClivoraColors.labelGray),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => context.push('/upgrade'),
                            child: const Text('Upgrade to Pro'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (files.isEmpty)
                    const Center(
                      child: Column(
                        children: [
                          Icon(Icons.folder_open_outlined, size: 64, color: ClivoraColors.labelGray),
                          SizedBox(height: 12),
                          Text('No files yet', style: TextStyle(fontWeight: FontWeight.w700)),
                          SizedBox(height: 8),
                          Text('Images shared in chat appear here automatically.'),
                        ],
                      ),
                    )
                  else
                    ...files.map((f) {
                      final file = f as File;
                      final locked = VaultService.isChatArchive(file.path);
                      return ListTile(
                        leading: Icon(locked ? Icons.chat_bubble_outline : Icons.insert_drive_file_outlined),
                        title: Text(file.path.split(Platform.pathSeparator).last),
                        subtitle: Text(
                          locked
                              ? '${VaultService.formatSize(file.lengthSync())} · from chat'
                              : VaultService.formatSize(file.lengthSync()),
                        ),
                        trailing: locked
                            ? const Icon(Icons.lock_outline, size: 18, color: ClivoraColors.labelGray)
                            : IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await VaultService.deleteFile(file.path);
                                  ref.invalidate(vaultFilesProvider);
                                },
                              ),
                      );
                    }),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Lightweight bottom sheet content helper for templates.
class ClivoraBottomSheetContent extends StatelessWidget {
  const ClivoraBottomSheetContent({
    super.key,
    required this.title,
    required this.onSave,
    required this.child,
  });

  final String title;
  final VoidCallback onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),
          child,
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(onPressed: onSave, child: const Text('Save'))),
            ],
          ),
        ],
      ),
    );
  }
}
