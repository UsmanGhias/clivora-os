import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/tracking_service.dart';
import '../../core/theme/clivora_colors.dart';

class TrackingTimeline extends ConsumerWidget {
  const TrackingTimeline({
    super.key,
    required this.entityType,
    required this.entityId,
  });

  final String entityType;
  final int entityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(
      trackingEventsProvider(TrackingQuery(entityType: entityType, entityId: entityId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timeline, size: 18, color: ClivoraColors.primaryPurple),
            const SizedBox(width: 8),
            Text('Status Tracking', style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 12),
        eventsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Could not load tracking history'),
          data: (events) {
            if (events.isEmpty) {
              return Text(
                'No status changes recorded yet. Updates are logged when you save.',
                style: Theme.of(context).textTheme.bodySmall,
              );
            }
            return Column(
              children: events.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: const BoxDecoration(
                          color: ClivoraColors.primaryPurple,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatStatus(e.status),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              DateFormat.yMMMd().add_jm().format(e.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (e.note.isNotEmpty)
                              Text(e.note, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
