import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/project_time_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/duration_formatter.dart';

class ProjectTimeTrackerCard extends ConsumerWidget {
  const ProjectTimeTrackerCard({super.key, required this.projectId, required this.projectName});

  final int projectId;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracker = ref.watch(projectTimeTrackerProvider);
    final totalsAsync = ref.watch(projectTrackedSecondsMapProvider);
    final totals = totalsAsync.valueOrNull ?? {};
    // ignore: unused_local_variable, tick drives rebuild every second
    final _ = tracker.tick;
    final seconds = tracker.elapsedSecondsFor(projectId, totals);
    final isActive = tracker.activeProjectId == projectId;
    final blocked = tracker.isRunning && !isActive;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [Color(0xFF1A1C2E), Color(0xFF2D3561)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isActive ? null : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? Colors.transparent : Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: isActive ? Colors.white70 : ClivoraColors.primary),
              const SizedBox(width: 8),
              Text(
                'Time Tracker',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              formatTrackedDurationLong(seconds),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isActive ? Colors.white : ClivoraColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              isActive ? 'Tracking $projectName' : '${formatTrackedDuration(seconds)} logged',
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.white70 : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: blocked
                      ? null
                      : () async {
                          try {
                            await ref.read(projectTimeTrackerProvider.notifier).toggle(projectId);
                          } on TimeTrackerConflictException catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Stop the timer on project #${e.activeProjectId} before starting another.',
                                ),
                              ),
                            );
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isActive ? Colors.white : null,
                    side: BorderSide(color: isActive ? Colors.white54 : Theme.of(context).dividerColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: Icon(isActive ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  label: Text(isActive ? 'Stop' : 'Start Timer'),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => ref.read(projectTimeTrackerProvider.notifier).stop(),
                  icon: const Icon(Icons.check),
                  tooltip: 'Stop & save',
                  style: IconButton.styleFrom(
                    backgroundColor: ClivoraColors.successGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class ProjectTimeBadge extends ConsumerWidget {
  const ProjectTimeBadge({super.key, required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracker = ref.watch(projectTimeTrackerProvider);
    final totalsAsync = ref.watch(projectTrackedSecondsMapProvider);
    final totals = totalsAsync.valueOrNull ?? {};
    final _ = tracker.tick;
    final seconds = tracker.elapsedSecondsFor(projectId, totals);
    if (seconds <= 0) return const SizedBox.shrink();

    final isActive = tracker.activeProjectId == projectId;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isActive ? Icons.timer : Icons.schedule,
          size: 14,
          color: isActive ? ClivoraColors.successGreen : ClivoraColors.labelGray,
        ),
        const SizedBox(width: 4),
        Text(
          formatTrackedDuration(seconds),
          style: TextStyle(
            fontSize: 12,
            color: isActive ? ClivoraColors.successGreen : ClivoraColors.labelGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
