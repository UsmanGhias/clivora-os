import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/cloud/client_project_resolver.dart';
import '../../core/cloud/cloud_notification_repository.dart';
import '../../core/cloud/cloud_project_repository.dart';
import '../../core/cloud/supabase_auth_helper.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/services/admin_management_service.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';

/// Client assigns tasks to their freelancer on shared projects.
class ClientTasksScreen extends ConsumerStatefulWidget {
  const ClientTasksScreen({super.key});

  @override
  ConsumerState<ClientTasksScreen> createState() => _ClientTasksScreenState();
}

class _ClientTasksScreenState extends ConsumerState<ClientTasksScreen> {
  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(clientSharedProjectsProvider);
    final tasksAsync = ref.watch(clientAssignedTasksProvider);

    return ClivoraScaffold(
      title: 'Assign Tasks',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAssignSheet(context),
        backgroundColor: ClivoraColors.clientAccent,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New task'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clientSharedProjectsProvider);
          ref.invalidate(clientAssignedTasksProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            projectsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
              data: (projects) {
                if (projects.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: ClivoraColors.clientAccentLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'No shared projects yet. Ask your freelancer to share a project before assigning tasks.',
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Text('Your tasks', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_outlined, size: 56, color: ClivoraColors.clientAccent.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text('No tasks assigned yet', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "New task" to request work from your freelancer.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: tasks.map((t) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                                Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                if (t.description.isNotEmpty)
                                  Text(t.description, style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 4),
                                Text(
                                  t.status.replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ClivoraColors.clientAccent),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: ClivoraColors.errorRed),
                            onPressed: () => ref.read(cloudClientTaskRepositoryProvider).delete(t.id),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignSheet(BuildContext context) async {
    final projects = await ref.read(clientSharedProjectsProvider.future);
    if (!context.mounted) return;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No shared projects. Ask your freelancer to share one first.')),
      );
      return;
    }

    ClientSharedProjectView? selected = projects.first;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Assign task to freelancer', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ClientSharedProjectView>(
                    initialValue: selected,
                    decoration: const InputDecoration(labelText: 'Project'),
                    items: projects
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                        .toList(),
                    onChanged: (v) => setModal(() => selected = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Task title', hintText: 'Required'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Details'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Enter a task title')),
                        );
                        return;
                      }
                      final project = selected;
                      final clientUid = SupabaseAuthHelper.currentUid;
                      final clientUser = ref.read(authStateProvider).valueOrNull;
                      if (project == null || clientUid == null || clientUser == null) return;

                      final freelancerUid = await resolveFreelancerUidForClientProject(
                        ref: ref,
                        project: project,
                        clientUserId: clientUser.id,
                      );
                      if (freelancerUid == null || freelancerUid.isEmpty) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Freelancer not linked yet. Ask them to share this project with your client email.',
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      try {
                        await ref.read(cloudClientTaskRepositoryProvider).assignTask(
                              clientUid: clientUid,
                              freelancerUid: freelancerUid,
                              title: title,
                              description: descCtrl.text.trim(),
                              projectShareId: shareIdForClientProject(project),
                              clientUser: clientUser,
                            );
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Could not send task: $e')),
                          );
                        }
                        return;
                      }

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Task sent to your freelancer')),
                        );
                      }
                    },
                    child: const Text('Send task'),
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
