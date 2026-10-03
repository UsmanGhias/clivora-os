import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/cloud/cloud_message_repository.dart';
import '../../core/cloud/cloud_notification_repository.dart';
import '../../core/services/milestone_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';

class _ClientMilestoneRow {
  const _ClientMilestoneRow({
    required this.milestone,
    required this.projectName,
    required this.freelancerEmail,
    required this.freelancerUserId,
  });

  final ProjectMilestone milestone;
  final String projectName;
  final String freelancerEmail;
  final int freelancerUserId;
}

final clientMilestonesProvider = FutureProvider<List<_ClientMilestoneRow>>((ref) async {
  final client = ref.watch(authStateProvider).valueOrNull;
  if (client == null) return [];
  final db = ref.read(databaseProvider);
  final projects = await db.watchProjectsForClient(client.id).first;
  final rows = <_ClientMilestoneRow>[];
  for (final project in projects) {
    final freelancer = await db.getFreelancerUserForClientProject(client.id, project.id);
    if (freelancer == null) continue;
    final milestones = await db.watchMilestonesForProject(freelancer.id, project.id).first;
    for (final m in milestones) {
      rows.add(
        _ClientMilestoneRow(
          milestone: m,
          projectName: project.name,
          freelancerEmail: freelancer.email,
          freelancerUserId: freelancer.id,
        ),
      );
    }
  }
  rows.sort((a, b) => b.milestone.updatedAt.compareTo(a.milestone.updatedAt));
  return rows;
});

/// Client view of shared project milestones with approve action.
class ClientMilestonesScreen extends ConsumerWidget {
  const ClientMilestonesScreen({super.key});

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    _ClientMilestoneRow row,
  ) async {
    final client = ref.read(authStateProvider).valueOrNull;
    if (client == null) return;
    final db = ref.read(databaseProvider);
    var wrote = false;

    try {
      await (db.update(db.projectMilestones)
            ..where((t) => t.id.equals(row.milestone.id))
            ..where((t) => t.ownerUserId.equals(row.freelancerUserId)))
          .write(
        ProjectMilestonesCompanion(
          status: const Value(MilestoneStatuses.approved),
          completedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      wrote = true;
    } catch (_) {
      wrote = false;
    }

    try {
      await ref.read(cloudNotificationRepositoryProvider).send(
            toEmail: row.freelancerEmail,
            title: 'Milestone approved: ${row.milestone.title}',
            body: '${client.name} approved "${row.milestone.title}" on ${row.projectName}.',
            kind: 'milestone',
          );
      await ref.read(cloudMessageRepositoryProvider).sendHybrid(
            fromUser: client,
            toEmail: row.freelancerEmail,
            subject: '[Milestone Approved] ${row.milestone.title}',
            body: 'Milestone "${row.milestone.title}" on ${row.projectName} was approved by ${client.name}.',
          );
    } catch (_) {}

    ref.invalidate(clientMilestonesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wrote
                ? 'Milestone approved'
                : 'Approval sent to your freelancer',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientMilestonesProvider);

    return ClivoraScaffold(
      title: 'Milestones',
      showBackButton: true,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.flag_outlined,
              message: 'No milestones on your shared projects yet.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final row = rows[i];
              final m = row.milestone;
              final canApprove = m.status == MilestoneStatuses.submitted ||
                  m.status == MilestoneStatuses.inProgress ||
                  m.status == MilestoneStatuses.pending;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(row.projectName, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      '${formatCurrency(m.amount, symbol: currencySymbol(m.currency))} · ${MilestoneStatuses.label(m.status)}',
                    ),
                    if (canApprove) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () => _approve(context, ref, row),
                          style: FilledButton.styleFrom(backgroundColor: ClivoraColors.clientAccent),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
