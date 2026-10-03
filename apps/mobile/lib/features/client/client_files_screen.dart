import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/clivora_colors.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';

/// Client file delivery lite, attachments linked to shared projects/contracts.
class ClientFilesScreen extends ConsumerWidget {
  const ClientFilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(clientSharedProjectsProvider);
    final contractsAsync = ref.watch(clientContractsProvider);

    return ClivoraScaffold(
      title: 'Files',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Deliverables & attachments',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Open a project or contract to view files your freelancer shared. Chat also supports image delivery.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ClivoraColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text('Shared projects', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          projectsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (projects) {
              if (projects.isEmpty) {
                return const EmptyState(
                  icon: Icons.folder_open_outlined,
                  message: 'No shared projects yet.',
                );
              }
              return Column(
                children: projects
                    .map(
                      (p) => ListTile(
                        leading: const Icon(Icons.folder_outlined, color: ClivoraColors.clientAccent),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(p.status),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Open ${p.name} from Home for timeline & files')),
                          );
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Contracts', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          contractsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (contracts) {
              if (contracts.isEmpty) {
                return const Text('No contracts yet', style: TextStyle(color: ClivoraColors.textSecondary));
              }
              return Column(
                children: contracts
                    .take(20)
                    .map(
                      (c) => ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(c.status),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
