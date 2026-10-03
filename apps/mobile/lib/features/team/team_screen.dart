import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/services/team_invite_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/form_validators.dart';
import '../../core/utils/navigation_helper.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  Future<void> _addMember() async {
    final isPro = ref.read(isProProvider);
    if (!isPro) {
      await requireProFeature(context, isPro: false, featureName: 'Team collaboration');
      return;
    }

    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    var role = 'member';
    int? selectedProjectId;

    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;

    final projects = await ref.read(databaseProvider).watchProjectsForUser(ownerId).first;
    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: const Text('Invite team member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'member', child: Text('Member')),
                    DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                  ],
                  onChanged: (v) => setModal(() => role = v ?? 'member'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: selectedProjectId,
                  decoration: const InputDecoration(labelText: 'Shared project (required)'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Select a project')),
                    ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                  ],
                  onChanged: (v) => setModal(() => selectedProjectId = v),
                ),
                const SizedBox(height: 8),
                Text(
                  'Teammates only get access to the project you select.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final nameErr = FormValidators.requiredField(nameCtrl.text, field: 'Name');
                final emailErr = FormValidators.email(emailCtrl.text, required: true);
                if (nameErr != null || emailErr != null || selectedProjectId == null) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Send invite'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    Project? project;
    for (final p in projects) {
      if (p.id == selectedProjectId) {
        project = p;
        break;
      }
    }

    final err = await ref.read(teamInviteServiceProvider).sendInvite(
          name: nameCtrl.text,
          email: emailCtrl.text,
          role: role,
          project: project,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Invite sent to ${emailCtrl.text.trim()}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamMembersProvider);
    final invitesAsync = ref.watch(pendingTeamInvitesProvider);
    final ownerInvitesAsync = ref.watch(ownerTeamInvitesProvider);
    final isPro = ref.watch(isProProvider);
    final inviteStatusByEmail = <String, String>{
      for (final invite in ownerInvitesAsync.valueOrNull ?? const <TeamInvite>[])
        invite.inviteeEmail.trim().toLowerCase(): invite.status,
    };

    return ClivoraScaffold(
      title: 'Team',
      showBackButton: true,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Pending invites',
            onPressed: () => context.push('/team-invites'),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? ClivoraColors.chipBackground
                  : ClivoraColors.darkBorder,
            ),
            icon: invitesAsync.maybeWhen(
              data: (list) => Badge(
                isLabelVisible: list.isNotEmpty,
                label: Text('${list.length}'),
                child: const Icon(Icons.mail_outline),
              ),
              orElse: () => const Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _addMember,
            icon: const Icon(Icons.person_add_outlined),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? ClivoraColors.chipBackground
                  : ClivoraColors.darkBorder,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isPro)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Card(
                color: ClivoraColors.primaryPurple.withValues(alpha: 0.08),
                child: ListTile(
                  leading: const Icon(Icons.groups_outlined, color: ClivoraColors.primaryPurple),
                  title: const Text('Team collaboration is Pro', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Invite teammates to work on a shared project.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/upgrade'),
                ),
              ),
            ),
          Expanded(
            child: teamAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (members) {
                if (members.isEmpty) {
                  return EmptyState(
                    icon: Icons.groups_outlined,
                    message: 'No team members yet',
                    actionLabel: isPro ? 'Invite teammate' : 'Upgrade to Pro',
                    onAction: isPro ? _addMember : () => context.push('/upgrade'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: members.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final m = members[index];
                    final status =
                        inviteStatusByEmail[m.email.trim().toLowerCase()];
                    final statusLabel = switch (status) {
                      'accepted' => 'Active',
                      'declined' => 'Declined',
                      'pending' => 'Invite pending',
                      _ => 'Invited',
                    };
                    return ListTile(
                      tileColor: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: ClivoraColors.primary.withValues(alpha: 0.12),
                        child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${m.email} · ${m.role} · $statusLabel'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: ClivoraColors.errorRed),
                        onPressed: () => ref.read(databaseProvider).deleteTeamMember(m.id),
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
}
