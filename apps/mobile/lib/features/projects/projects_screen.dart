import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/plan_limits.dart';
import '../../core/services/sync_outbox_service.dart';
import '../../core/utils/navigation_helper.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_bottom_sheet.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/filter_chip_row.dart';
import '../../shared/widgets/project_time_tracker.dart';
import '../../shared/widgets/stat_summary_card.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final _searchController = TextEditingController();
  String _status = 'all';
  String? _search;
  bool _kanban = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showEntityConflictDialog(context, ref);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onAddProject() async {
    await tryOpenWithPlanCheck(
      context,
      ref: ref,
      canAdd: () => ref.read(planLimitServiceProvider).canAddProject(),
      path: '/projects/new',
      resource: 'projects',
      max: PlanLimits.freeMaxProjects,
    );
  }

  Future<void> _moveStatus(dynamic project, String status) async {
    await ref.read(databaseProvider).updateProject(
          project.copyWith(status: status, updatedAt: DateTime.now()),
        );
    ref.invalidate(projectsProvider(ProjectFilter(search: _search, status: _status)));
    ref.invalidate(projectStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ProjectFilter(search: _search, status: _kanban ? 'all' : _status);
    final projectsAsync = ref.watch(projectsProvider(filter));
    final statsAsync = ref.watch(projectStatsProvider);
    final projectCountAsync = ref.watch(projectCountProvider);

    return ClivoraScaffold(
      title: 'Projects',
      showMessagesButton: true,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: _kanban ? 'List view' : 'Pipeline view',
            onPressed: () => setState(() => _kanban = !_kanban),
            icon: Icon(_kanban ? Icons.view_list : Icons.view_kanban_outlined),
          ),
          ClivoraIconButton(icon: Icons.add, onPressed: _onAddProject),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _search = v.isEmpty ? null : v),
            decoration: const InputDecoration(
              hintText: 'Search projects...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          statsAsync.when(
            loading: () => const SizedBox(height: 80),
            error: (_, _) => const SizedBox.shrink(),
            data: (stats) => StatSummaryCard(
              items: [
                StatItem(label: 'Active', value: '${stats.active}'),
                StatItem(label: 'Earned', value: formatCurrency(stats.earned)),
                StatItem(label: 'Hours', value: stats.trackedHoursLabel),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!_kanban)
            FilterChipRow(
              options: const ['all', 'not_started', 'in_progress', 'completed'],
              selected: _status,
              onSelected: (v) => setState(() => _status = v),
            ),
          if (!_kanban) const SizedBox(height: 8),
          projectCountAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (count) => PlanLimitBanner(
              current: count,
              max: PlanLimits.freeMaxProjects,
              resource: 'projects',
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: projectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (projects) {
                if (projects.isEmpty) {
                  final total = projectCountAsync.valueOrNull ?? 0;
                  final isFiltered = _search != null || (!_kanban && _status != 'all');
                  if (isFiltered && total > 0) {
                    return EmptyState(
                      icon: Icons.folder_outlined,
                      message: _search != null ? 'No projects match your search' : 'No ${_statusLabel(_status).toLowerCase()} projects',
                      actionLabel: 'Show all projects',
                      onAction: () {
                        _searchController.clear();
                        setState(() {
                          _search = null;
                          _status = 'all';
                        });
                      },
                    );
                  }
                  return EmptyState(
                    icon: Icons.folder_outlined,
                    message: 'Create a project to track scope, milestones, and billable time.',
                    actionLabel: 'Create project',
                    onAction: _onAddProject,
                  );
                }
                if (_kanban) {
                  const cols = [
                    ('not_started', 'Backlog'),
                    ('in_progress', 'In progress'),
                    ('on_hold', 'On hold'),
                    ('completed', 'Done'),
                  ];
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final col in cols)
                        SizedBox(
                          width: 260,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${col.$2} (${projects.where((p) => p.status == col.$1 || (col.$1 == 'not_started' && p.status == 'not_started')).length})',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView(
                                    children: [
                                      for (final p in projects.where((p) {
                                        if (col.$1 == 'in_progress') {
                                          return p.status == 'in_progress' || p.status == 'active';
                                        }
                                        return p.status == col.$1;
                                      }))
                                        Card(
                                          child: ListTile(
                                            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                            subtitle: Text(formatCurrency(p.budget, symbol: currencySymbol(p.currency))),
                                            onTap: () => openFormRoute(context, '/projects/${p.id}/edit'),
                                            trailing: PopupMenuButton<String>(
                                              onSelected: (v) => _moveStatus(p, v),
                                              itemBuilder: (_) => [
                                                for (final c in cols)
                                                  if (c.$1 != p.status)
                                                    PopupMenuItem(value: c.$1, child: Text('Move → ${c.$2}')),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                }
                return ListView.separated(
                  itemCount: projects.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = projects[index];
                    return Dismissible(
                      key: ValueKey(p.id),
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
                                title: const Text('Delete project?'),
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
                                kind: 'crm_project_delete',
                                payload: {'localId': p.id},
                                isTombstone: true,
                              ),
                            );
                        await ref.read(databaseProvider).deleteProject(p.id);
                      },
                      child: ListTile(
                        onTap: () => openFormRoute(context, '/projects/${p.id}/edit'),
                        tileColor: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        leading: const Icon(Icons.work_outline),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_statusLabel(p.status)),
                            ProjectTimeBadge(projectId: p.id),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'milestones') {
                              context.push('/projects/${p.id}/milestones');
                            }
                            if (v == 'time') {
                              context.push('/projects/${p.id}/time');
                            }
                            if (v == 'edit') {
                              openFormRoute(context, '/projects/${p.id}/edit');
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'milestones', child: Text('Milestones')),
                            PopupMenuItem(value: 'time', child: Text('Track time')),
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                          ],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(formatCurrency(p.budget, symbol: currencySymbol(p.currency))),
                              Icon(Icons.more_horiz, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ],
                          ),
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

  String _statusLabel(String status) {
    switch (status) {
      case 'not_started':
        return 'Not Started';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}
