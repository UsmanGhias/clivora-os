import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/project_time_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/entity_activity_timeline.dart';
import '../../shared/widgets/project_time_tracker.dart';

/// Dedicated time tracking screen for a project (separate from edit form).
class ProjectTimeTrackerScreen extends ConsumerWidget {
  const ProjectTimeTrackerScreen({super.key, required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectsProvider(const ProjectFilter()));

    return projectAsync.when(
      loading: () => const ClivoraScaffold(
        title: 'Time Tracker',
        showBackButton: true,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ClivoraScaffold(
        title: 'Time Tracker',
        showBackButton: true,
        body: Center(child: Text('Error: $e')),
      ),
      data: (projects) {
        final project = projects.where((p) => p.id == projectId).firstOrNull;
        if (project == null) {
          return ClivoraScaffold(
            title: 'Time Tracker',
            showBackButton: true,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Project not found'),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => context.pop(), child: const Text('Go back')),
                ],
              ),
            ),
          );
        }

        final tracker = ref.watch(projectTimeTrackerProvider);
        final otherActive = tracker.isRunning && tracker.activeProjectId != projectId;

        return ClivoraScaffold(
          title: 'Time Tracker',
          showBackButton: true,
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(project.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                project.status.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ClivoraColors.labelGray,
                ),
              ),
              if (otherActive) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ClivoraColors.warningOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ClivoraColors.warningOrange.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: ClivoraColors.warningOrange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Another project is being tracked. Stop that timer before starting here.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ProjectTimeTrackerCard(projectId: projectId, projectName: project.name),
              const SizedBox(height: 24),
              Text('Tracking activity', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: EntityActivityTimeline(entityType: 'project', entityId: projectId),
              ),
            ],
          ),
        );
      },
    );
  }
}
