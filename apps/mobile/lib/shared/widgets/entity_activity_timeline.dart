import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/audit_log_service.dart';
import '../../core/services/tracking_service.dart';
import '../../core/theme/clivora_colors.dart';

/// Unified activity timeline combining status tracking and audit events.
class EntityActivityTimeline extends ConsumerWidget {
  const EntityActivityTimeline({
    super.key,
    required this.entityType,
    required this.entityId,
    this.title = 'Activity',
  });

  final String entityType;
  final int entityId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingAsync = ref.watch(
      trackingEventsProvider(TrackingQuery(entityType: entityType, entityId: entityId)),
    );
    final auditAsync = ref.watch(auditLogsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, size: 18, color: ClivoraColors.primaryPurple),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 12),
        trackingAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Could not load activity'),
          data: (tracking) {
            final audit = auditAsync.valueOrNull ?? [];
            final filteredAudit = audit.where((a) {
              try {
                return a.payload.contains('"entityType":"$entityType"') &&
                    a.payload.contains('"entityId":$entityId');
              } catch (_) {
                return false;
              }
            }).toList();

            final items = <_TimelineItem>[];
            for (final e in tracking) {
              items.add(_TimelineItem(
                label: _formatStatus(e.status),
                subtitle: e.note.isNotEmpty ? e.note : 'Status update',
                at: e.createdAt,
                icon: Icons.swap_horiz_rounded,
              ));
            }
            for (final a in filteredAudit) {
              items.add(_TimelineItem(
                label: a.eventType.replaceFirst('audit_', '').replaceAll('_', ' '),
                subtitle: a.userEmail.isNotEmpty ? a.userEmail : a.userName,
                at: a.createdAt,
                icon: Icons.verified_user_outlined,
              ));
            }
            items.sort((a, b) => b.at.compareTo(a.at));

            if (items.isEmpty) {
              return Text(
                'No activity yet. Changes, payments, and status updates appear here.',
                style: Theme.of(context).textTheme.bodySmall,
              );
            }

            return Column(
              children: items.map((item) => _TimelineRow(item: item)).toList(),
            );
          },
        ),
      ],
    );
  }

  String _formatStatus(String status) {
    return status.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }
}

class _TimelineItem {
  const _TimelineItem({
    required this.label,
    required this.subtitle,
    required this.at,
    required this.icon,
  });

  final String label;
  final String subtitle;
  final DateTime at;
  final IconData icon;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});

  final _TimelineItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 16, color: ClivoraColors.primaryPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  DateFormat.yMMMd().add_jm().format(item.at),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (item.subtitle.isNotEmpty)
                  Text(item.subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
