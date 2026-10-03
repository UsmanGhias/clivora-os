import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/constants/plan_limits.dart';
import '../../core/utils/plan_limit_dialog.dart';
import '../../core/services/email_verification_service.dart';
import '../../core/services/sync_outbox_service.dart';
import '../../core/services/task_reminder_service.dart';
import '../../core/services/tracking_service.dart';
import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/filter_chip_row.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _status = 'all';

  Future<void> _openNewTask() async {
    if (!await requireEmailVerified(context, ref, actionLabel: 'create tasks')) return;
    if (!mounted) return;
    context.push('/tasks/new');
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider(TaskFilter(status: _status)));

    return ClivoraScaffold(
      title: 'Tasks',
      subtitle: 'Local tasks sync to cloud workspace_tasks when flag on · see Workspace tasks',
      showBackButton: true,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Workspace tasks (web parity)',
            icon: const Icon(Icons.cloud_outlined),
            onPressed: () => context.push('/workspace-tasks'),
          ),
          ClivoraIconButton(
            icon: Icons.add,
            onPressed: _openNewTask,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterChipRow(
            options: const ['all', 'pending', 'completed'],
            selected: _status,
            onSelected: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return EmptyState(
                    icon: Icons.task_alt_outlined,
                    message: 'No tasks yet',
                    actionLabel: 'Create your first task',
                    onAction: _openNewTask,
                  );
                }
                return ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Dismissible(
                      key: ValueKey(task.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete task?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                ],
                              ),
                            ) ??
                            false;
                      },
                      onDismissed: (_) async {
                        await ref.read(databaseProvider).deleteTask(task.id);
                        await ref.read(syncOutboxServiceProvider).enqueue(
                              SyncOutboxItem(
                                kind: 'workspace_task',
                                payload: {'localId': task.id},
                                isTombstone: true,
                              ),
                            );
                      },
                      child: ListTile(
                        onTap: () => context.push('/tasks/${task.id}/edit'),
                        tileColor: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        leading: Checkbox(
                          value: task.completed,
                          activeColor: ClivoraColors.successGreen,
                          onChanged: (v) async {
                            final completed = v ?? false;
                            final updated = task.copyWith(
                              completed: completed,
                              status: completed ? 'completed' : 'pending',
                              updatedAt: DateTime.now(),
                            );
                            await ref.read(databaseProvider).updateTask(updated);
                            await ref.read(syncOutboxServiceProvider).enqueue(
                                  SyncOutboxItem(
                                    kind: 'workspace_task',
                                    payload: {'localId': task.id},
                                  ),
                                );
                            if (completed) {
                              await ref.read(trackingServiceProvider).notifyTaskCompleted(updated);
                            }
                          },
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: task.completed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: task.dueDate != null
                            ? Text(DateFormat('MMM d, yyyy').format(task.dueDate!))
                            : null,
                        trailing: _priorityIcon(task.priority),
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

  Widget _priorityIcon(String priority) {
    Color color;
    switch (priority) {
      case 'high':
        color = ClivoraColors.errorRed;
      case 'low':
        color = ClivoraColors.labelGray;
      default:
        color = ClivoraColors.warningOrange;
    }
    return Icon(Icons.flag, color: color, size: 18);
  }
}

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.taskId});

  final int? taskId;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _priority = 'medium';
  DateTime? _dueDate;
  int? _selectedCustomerId;
  int? _selectedProjectId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.taskId != null) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    final task = await ref.read(databaseProvider).getTask(widget.taskId!);
    if (task != null && mounted) {
      _titleController.text = task.title;
      _descController.text = task.description;
      _priority = task.priority;
      _dueDate = task.dueDate;
      _selectedCustomerId = task.customerId;
      _selectedProjectId = task.projectId;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }
    final db = ref.read(databaseProvider);
    if (widget.taskId != null) {
      final existing = await db.getTask(widget.taskId!);
      if (existing != null) {
        final updated = existing.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          priority: _priority,
          customerId: Value(_selectedCustomerId),
          projectId: Value(_selectedProjectId),
          dueDate: Value(_dueDate),
          updatedAt: DateTime.now(),
        );
        await db.updateTask(updated);
        await ref.read(taskReminderServiceProvider).scheduleForTask(updated);
        await ref.read(syncOutboxServiceProvider).enqueue(
              SyncOutboxItem(kind: 'workspace_task', payload: {'localId': widget.taskId}),
            );
      }
    } else {
      if (!await requireEmailVerified(context, ref, actionLabel: 'create tasks')) {
        return;
      }
      if (!await ref.read(planLimitServiceProvider).canAddTaskToProject(_selectedProjectId)) {
        if (mounted) {
          final upgrade = await showPlanLimitDialog(
            context,
            resource: 'tasks per project',
            max: PlanLimits.freeMaxTasksPerProject,
          );
          if (upgrade && mounted) context.push('/upgrade');
        }
        return;
      }
      final id = await db.insertTask(TasksCompanion.insert(
        ownerUserId: ref.read(authStateProvider).valueOrNull!.id,
        title: _titleController.text.trim(),
        description: Value(_descController.text.trim()),
        priority: Value(_priority),
        customerId: Value(_selectedCustomerId),
        projectId: Value(_selectedProjectId),
        dueDate: Value(_dueDate),
      ));
      final task = await db.getTask(id);
      if (task != null) {
        await ref.read(taskReminderServiceProvider).scheduleForTask(task);
      }
      await ref.read(syncOutboxServiceProvider).enqueue(
            SyncOutboxItem(kind: 'workspace_task', payload: {'localId': id}),
          );
    }
    if (mounted) context.pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final customersAsync = ref.watch(customersProvider(null));
    final projectsAsync = ref.watch(projectsProvider(const ProjectFilter()));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskId != null ? 'Edit Task' : 'New Task'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'TASK TITLE', hintText: 'What needs to be done?'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'DESCRIPTION', hintText: 'Optional details'),
          ),
          const SizedBox(height: 16),
          const Text('LINK TO CLIENT / PROJECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          customersAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (customers) => DropdownButtonFormField<int?>(
              initialValue: _selectedCustomerId,
              decoration: const InputDecoration(labelText: 'Customer (optional)'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('None')),
                ...customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.contactPerson))),
              ],
              onChanged: (v) => setState(() {
                _selectedCustomerId = v;
                _selectedProjectId = null;
              }),
            ),
          ),
          const SizedBox(height: 16),
          projectsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (projects) {
              final filtered = _selectedCustomerId == null
                  ? projects
                  : projects.where((p) => p.customerId == _selectedCustomerId).toList();
              return DropdownButtonFormField<int?>(
                initialValue: filtered.any((p) => p.id == _selectedProjectId) ? _selectedProjectId : null,
                decoration: const InputDecoration(labelText: 'Project (optional)'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('None')),
                  ...filtered.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                ],
                onChanged: (v) => setState(() => _selectedProjectId = v),
              );
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'PRIORITY'),
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
            title: const Text('Due Date'),
            subtitle: Text(_dueDate != null ? DateFormat('MMM d, yyyy').format(_dueDate!) : 'Not set'),
            trailing: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
          ),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: _save, child: const Text('Save Task')),
        ],
      ),
    );
  }
}
