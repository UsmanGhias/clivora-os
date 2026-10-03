import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/team_invite_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';

/// Pending team invites for the signed-in user to accept or decline.
class TeamInvitesScreen extends ConsumerWidget {
  const TeamInvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(pendingTeamInvitesProvider);

    return ClivoraScaffold(
      title: 'Team invites',
      showBackButton: true,
      body: invitesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (invites) {
          if (invites.isEmpty) {
            return const EmptyState(
              icon: Icons.mail_outline,
              message: 'No pending team invites',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: invites.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final invite = invites[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.projectName.isNotEmpty ? invite.projectName : 'Team collaboration',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Role: ${invite.role}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (invite.projectName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'You will get access to this shared project only.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ClivoraColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final err = await ref.read(teamInviteServiceProvider).declineInvite(invite);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err ?? 'Invite declined')),
                                );
                              },
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                final err = await ref.read(teamInviteServiceProvider).acceptInvite(invite);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err ?? 'Invite accepted. Shared project access granted.')),
                                );
                              },
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
