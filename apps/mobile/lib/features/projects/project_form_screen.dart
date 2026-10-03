import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/cloud/cloud_project_repository.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/services/tracking_service.dart';
import '../../data/database/database.dart';
import '../../core/constants/currencies.dart';
import '../../core/constants/plan_limits.dart';
import '../../core/utils/crm_refresh.dart';
import '../../core/utils/plan_limit_dialog.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/user_messages.dart';
import '../../core/services/email_verification_service.dart';
import '../../core/services/sync_outbox_service.dart';
import '../../data/models/invoice_line_item.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/step_progress_card.dart';

class ProjectFormScreen extends ConsumerStatefulWidget {
  const ProjectFormScreen({super.key, this.projectId});

  final int? projectId;

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  int _step = 1;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _customerSearchController = TextEditingController();
  int? _selectedCustomerId;
  String _status = 'not_started';
  String? _previousStatus;
  String _priority = 'medium';
  String _currency = kDefaultCurrency;
  DateTime? _startDate;
  DateTime? _deadline;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.projectId != null) {
      _loadProject();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadProject() async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final project = await ref.read(databaseProvider).getProjectForUser(ownerId, widget.projectId!);
    if (project != null && mounted) {
      _nameController.text = project.name;
      _descriptionController.text = project.description;
      _budgetController.text = project.budget > 0 ? project.budget.toString() : '';
      _currency = project.currency.isNotEmpty ? project.currency : kDefaultCurrency;
      _selectedCustomerId = project.customerId;
      _status = project.status;
      _previousStatus = project.status;
      _priority = project.priority;
      _startDate = project.startDate;
      _deadline = project.deadline;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project name is required')),
      );
      return;
    }
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    final ownerId = ref.read(authStateProvider).valueOrNull!.id;
    final budget = double.tryParse(_budgetController.text.trim()) ?? 0;
    int? savedId = widget.projectId;

    if (widget.projectId != null) {
      final existing = await db.getProjectForUser(ownerId, widget.projectId!);
      if (existing != null) {
        await db.updateProject(
          existing.copyWith(
            name: _nameController.text.trim(),
            customerId: _selectedCustomerId!,
            description: _descriptionController.text.trim(),
            budget: budget,
            currency: _currency,
            status: _status,
            priority: _priority,
            startDate: Value(_startDate),
            deadline: Value(_deadline),
            updatedAt: DateTime.now(),
          ),
        );
        savedId = widget.projectId;
      }
    } else {
      if (!await requireEmailVerified(context, ref, actionLabel: 'add projects')) {
        return;
      }
      if (!await ref.read(planLimitServiceProvider).canAddProject()) {
        if (mounted) {
          final upgrade = await showPlanLimitDialog(
            context,
            resource: 'projects',
            max: PlanLimits.freeMaxProjects,
          );
          if (upgrade && mounted) context.push('/upgrade');
        }
        return;
      }
      savedId = await db.insertProject(
        ProjectsCompanion.insert(
          ownerUserId: ownerId,
          customerId: _selectedCustomerId!,
          name: _nameController.text.trim(),
          description: Value(_descriptionController.text.trim()),
          budget: Value(budget),
          currency: Value(_currency),
          status: Value(_status),
          priority: Value(_priority),
          startDate: Value(_startDate),
          deadline: Value(_deadline),
        ),
      );
    }

    if (savedId != null && (_previousStatus != _status || widget.projectId == null)) {
      await ref.read(trackingServiceProvider).logStatusChange(
            entityType: 'project',
            entityId: savedId,
            status: _status,
            note: widget.projectId == null ? 'Project created' : 'Status updated',
          );
    }

    if (savedId != null) {
      await ref.read(syncOutboxServiceProvider).enqueue(
            SyncOutboxItem(kind: 'crm_project', payload: {'localId': savedId}),
          );
      final customer = await db.getCustomerForUser(ownerId, _selectedCustomerId!);
      if (customer != null) {
        final emails = parseStringList(customer.emails);
        if (emails.isNotEmpty) {
          await db.linkProjectToClientEmail(
            projectId: savedId,
            freelancerUserId: ownerId,
            clientEmail: emails.first,
          );
          final project = await db.getProjectForUser(ownerId, savedId);
          final freelancer = ref.read(authStateProvider).valueOrNull;
          if (project != null && freelancer != null) {
            await ref.read(cloudProjectRepositoryProvider).shareHybrid(
              freelancer: freelancer,
              clientEmail: emails.first,
              localProjectId: savedId,
              project: project,
            );
          }
        }
      }
    }

    if (mounted) {
      invalidateCrmData(ref, projects: true);
      ClivoraUserMessages.showProjectSaved(
        context,
        name: _nameController.text.trim(),
        currency: _currency,
        budget: budget,
        isNew: widget.projectId == null,
      );
      context.pop();
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _deadline = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final customersAsync = ref.watch(customersProvider(null));

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
                      widget.projectId != null ? 'Edit Project' : 'New Project',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  StepProgressCard(
                    currentStep: _step,
                    totalSteps: 2,
                    title: _step == 1 ? 'Customer & Info' : 'Details',
                    nextLabel: _step == 1 ? 'Details' : 'Save',
                  ),
                  const SizedBox(height: 20),
                  if (_step == 1) ...[
                    const ClivoraFieldLabel(label: 'Customer', required: true),
                    customersAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Could not load customers'),
                      data: (customers) {
                        if (customers.isEmpty) {
                          return const Text('No customers yet. Add one first.');
                        }
                        final unique = {for (final c in customers) c.id: c}.values.toList();
                        final validIds = unique.map((c) => c.id).toSet();
                        final selectedId = _selectedCustomerId != null && validIds.contains(_selectedCustomerId)
                            ? _selectedCustomerId
                            : null;
                        return DropdownButtonFormField<int>(
                          initialValue: selectedId,
                          decoration: const InputDecoration(hintText: 'Select a customer'),
                          items: unique
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    c.company.isNotEmpty
                                        ? '${c.contactPerson} · ${c.company}'
                                        : c.contactPerson,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selectedCustomerId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
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
                            controller: _nameController,
                            label: 'Project Name',
                            hint: 'e.g. Website Redesign, Marketing Campaign',
                            required: true,
                            prefixIcon: Icons.description_outlined,
                          ),
                          const SizedBox(height: 16),
                          ClivoraTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            hint: 'Scope, deliverables, and key details.',
                            maxLines: 4,
                            prefixIcon: Icons.notes_outlined,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
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
                          ClivoraTextField(controller: _budgetController, label: 'Budget', hint: '0', keyboardType: TextInputType.number),
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
                          const ClivoraFieldLabel(label: 'Status'),
                          DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration: const InputDecoration(),
                            items: const [
                              DropdownMenuItem(value: 'not_started', child: Text('Not Started')),
                              DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                              DropdownMenuItem(value: 'completed', child: Text('Completed')),
                            ],
                            onChanged: (v) => setState(() => _status = v ?? 'not_started'),
                          ),
                          const SizedBox(height: 16),
                          const ClivoraFieldLabel(label: 'Priority'),
                          DropdownButtonFormField<String>(
                            initialValue: _priority,
                            decoration: const InputDecoration(),
                            items: const [
                              DropdownMenuItem(value: 'low', child: Text('Low')),
                              DropdownMenuItem(value: 'medium', child: Text('Medium')),
                              DropdownMenuItem(value: 'high', child: Text('High')),
                            ],
                            onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Start Date'),
                            subtitle: Text(_startDate != null ? DateFormat.yMMMd().format(_startDate!) : 'Not set'),
                            trailing: TextButton(onPressed: () => _pickDate(true), child: const Text('Pick')),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Deadline'),
                            subtitle: Text(_deadline != null ? DateFormat.yMMMd().format(_deadline!) : 'Not set'),
                            trailing: TextButton(onPressed: () => _pickDate(false), child: const Text('Pick')),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.projectId != null) ...[
                    const SizedBox(height: 20),
                    _LinkedProjectPanel(projectId: widget.projectId!),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/projects/${widget.projectId}/time'),
                      icon: const Icon(Icons.timer_outlined),
                      label: const Text('Open time tracker'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_step == 1) {
                      if (_nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Project name is required')),
                        );
                        return;
                      }
                      if (_selectedCustomerId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a customer')),
                        );
                        return;
                      }
                      setState(() => _step = 2);
                    } else {
                      _save();
                    }
                  },
                  child: Text(_step == 1 ? 'Next' : 'Save Project'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedProjectPanel extends ConsumerWidget {
  const _LinkedProjectPanel({required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider(null));
    final tasksAsync = ref.watch(tasksProvider(const TaskFilter()));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Linked tracking', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          invoicesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (invoices) {
              final linked = invoices.where((i) => i.projectId == projectId).toList();
              if (linked.isEmpty) {
                return const Text('No invoices linked yet', style: TextStyle(fontSize: 13));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: linked.map((inv) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_long_outlined, size: 20),
                    title: Text(inv.invoiceNumber),
                    subtitle: Text('${inv.status} · ${formatCurrency(inv.total, symbol: currencySymbol(inv.currency))}'),
                    onTap: () => context.push('/invoices/${inv.id}/edit'),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          tasksAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (tasks) {
              final linked = tasks.where((t) => t.projectId == projectId).toList();
              if (linked.isEmpty) {
                return const Text('No tasks linked yet', style: TextStyle(fontSize: 13));
              }
              return Column(
                children: linked.take(5).map((task) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      task.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: task.completed ? ClivoraColors.successGreen : null,
                    ),
                    title: Text(task.title),
                    subtitle: Text(task.completed ? 'Completed' : task.priority),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
