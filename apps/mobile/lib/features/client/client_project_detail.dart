import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/cloud/cloud_project_repository.dart';
import '../../core/services/review_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/duration_formatter.dart';
import '../../core/utils/navigation_helper.dart';
import 'client_portal_screen.dart' show ClientTrackingKey, clientProjectSecondsProvider;

/// Opens project detail sheet with live tracked seconds.
Future<void> openClientProjectDetail(
  BuildContext context,
  WidgetRef ref,
  ClientSharedProjectView view,
  int? clientUserId,
) async {
  var seconds = 0;
  if (clientUserId != null && view.localProject != null && !view.isCloudOnly) {
    seconds = await ref.read(
      clientProjectSecondsProvider(
        ClientTrackingKey(clientUserId: clientUserId, projectId: view.localProject!.id),
      ).future,
    );
  }
  if (context.mounted) {
    await showClientProjectDetail(context, ref, project: view, trackedSeconds: seconds);
  }
}

/// Full project detail for clients, tap any shared project card.
Future<void> showClientProjectDetail(
  BuildContext context,
  WidgetRef ref, {
  required ClientSharedProjectView project,
  required int trackedSeconds,
}) async {
  final status = project.status.replaceAll('_', ' ');
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.45,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ClivoraColors.clientAccentLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.folder_open_rounded, color: ClivoraColors.clientAccent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                    Text(status.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ClivoraColors.clientAccent)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ProjectPipeline(status: project.status),
          const SizedBox(height: 16),
          if (project.budget > 0)
            _DetailRow(
              icon: Icons.payments_outlined,
              label: 'Budget',
              value: '${formatCurrency(project.budget, symbol: currencySymbol(project.currency))} (${project.currency})',
            ),
          _DetailRow(
            icon: Icons.timer_outlined,
            label: 'Time tracked',
            value: project.isCloudOnly ? 'Synced from freelancer' : formatTrackedDuration(trackedSeconds),
          ),
          if (project.deadline != null)
            _DetailRow(
              icon: Icons.event_outlined,
              label: 'Deadline',
              value: DateFormat.yMMMd().format(project.deadline!.toLocal()),
            ),
          if (project.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Scope', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(project.description),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openFormRoute(context, '/client-activity');
                  },
                  icon: const Icon(Icons.timeline_outlined),
                  label: const Text('Updates'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openFormRoute(context, '/client-messages');
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message'),
                  style: FilledButton.styleFrom(backgroundColor: ClivoraColors.clientAccent),
                ),
              ),
            ],
          ),
          if (project.status == 'completed') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ClivoraColors.successGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: ClivoraColors.successGreen),
                  SizedBox(width: 10),
                  Expanded(child: Text('This project is marked completed by your freelancer.')),
                ],
              ),
            ),
            if (project.localProject != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final rating = await _pickRating(ctx);
                  if (rating == null) return;
                  final commentCtrl = TextEditingController();
                  if (!ctx.mounted) return;
                  final ok = await showDialog<bool>(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Leave a review'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$rating / 5 stars'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: commentCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(labelText: 'Feedback (optional)'),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Submit')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  final client = ref.read(authStateProvider).valueOrNull;
                  final local = project.localProject!;
                  final err = await ref.read(reviewServiceProvider).submitClientReview(
                        projectId: local.id,
                        ownerUserId: local.ownerUserId,
                        rating: rating,
                        comment: commentCtrl.text,
                        customerId: local.customerId,
                        clientEmail: client?.email ?? '',
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err ?? 'Thanks! Your review was submitted.')),
                    );
                  }
                },
                icon: const Icon(Icons.star_outline),
                label: const Text('Leave a review'),
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

Future<int?> _pickRating(BuildContext context) async {
  return showDialog<int>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Rate this project'),
      children: List.generate(
        5,
        (i) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, i + 1),
          child: Row(
            children: [
              ...List.generate(i + 1, (_) => const Icon(Icons.star, color: ClivoraColors.accent, size: 20)),
              const SizedBox(width: 8),
              Text('${i + 1} star${i == 0 ? '' : 's'}'),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ClivoraColors.clientAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual status pipeline for client project detail (Atrium-inspired UX).
class _ProjectPipeline extends StatelessWidget {
  const _ProjectPipeline({required this.status});
  final String status;

  static const _stages = ['not_started', 'in_progress', 'review', 'completed'];

  int get _index {
    final s = status.toLowerCase();
    if (s.contains('complete') || s == 'done') return 3;
    if (s.contains('review')) return 2;
    if (s.contains('progress') || s == 'active') return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Progress', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < _stages.length; i++) ...[
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= idx ? ClivoraColors.clientAccent : ClivoraColors.borderLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _stages[i].replaceAll('_', ' '),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: i == idx ? FontWeight.w800 : FontWeight.w500,
                        color: i <= idx ? ClivoraColors.clientAccent : ClivoraColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < _stages.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }
}
