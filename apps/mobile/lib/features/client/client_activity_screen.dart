import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/cloud/cloud_project_repository.dart';
import '../../core/theme/clivora_colors.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import 'client_project_detail.dart';

/// Client activity feed, updates across all shared projects.
class ClientActivityScreen extends ConsumerWidget {
  const ClientActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(clientActivityProvider);
    final projectsAsync = ref.watch(clientSharedProjectsProvider);
    final clientUserId = ref.watch(authStateProvider).valueOrNull?.id;

    return ClivoraScaffold(
      title: 'Updates',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clientActivityProvider);
          ref.invalidate(clientSharedProjectsProvider);
        },
        child: activityAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 64, color: ClivoraColors.clientAccent.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('No updates yet', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'When your freelancer logs time or posts project updates, they will appear here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }
            final projects = projectsAsync.valueOrNull ?? [];
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                ClientSharedProjectView? projectView;
                for (final p in projects) {
                  if (p.localProject?.id == item.projectId || p.name == item.projectName) {
                    projectView = p;
                    break;
                  }
                }
                return _ActivityTile(
                  item: item,
                  onTap: projectView != null && clientUserId != null
                      ? () => openClientProjectDetail(context, ref, projectView!, clientUserId)
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, this.onTap});

  final ClientActivityItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('MMM d · h:mm a').format(item.createdAt.toLocal());
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ClivoraColors.clientAccentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.timeline_rounded, color: ClivoraColors.clientAccent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.projectName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.status.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ClivoraColors.clientAccent,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(item.note, style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const SizedBox(height: 6),
                    Text(time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ClivoraColors.labelGray)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right, color: ClivoraColors.labelGray),
            ],
          ),
        ),
      ),
    );
  }
}
