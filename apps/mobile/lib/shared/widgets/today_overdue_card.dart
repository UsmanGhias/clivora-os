import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/clivora_colors.dart';
import '../../data/providers/app_providers.dart';

/// Dashboard card surfacing overdue invoices and pending tasks.
class TodayOverdueCard extends ConsumerWidget {
  const TodayOverdueCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final tasksAsync = ref.watch(tasksProvider(const TaskFilter(status: 'pending')));
    final outstanding = statsAsync.valueOrNull?.outstanding ?? 0;
    final pendingTasks = tasksAsync.valueOrNull?.length ?? 0;

    if (outstanding <= 0 && pendingTasks == 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 16),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? ClivoraColors.darkBorder
                : scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.today_outlined, color: ClivoraColors.warningOrange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Today',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (outstanding > 0)
                _ActionRow(
                  icon: Icons.receipt_long_outlined,
                  iconColor: ClivoraColors.errorRed,
                  title: 'Outstanding invoices',
                  subtitle: 'Need attention',
                  onTap: () => context.push('/invoices?filter=outstanding'),
                ),
              if (pendingTasks > 0)
                _ActionRow(
                  icon: Icons.task_alt_outlined,
                  iconColor: ClivoraColors.primary,
                  title: '$pendingTasks pending task${pendingTasks == 1 ? '' : 's'}',
                  subtitle: 'Tap to review and complete',
                  onTap: () => context.push('/tasks'),
                ),
              if (outstanding <= 0 && pendingTasks > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 44, bottom: 6, top: 4),
                  child: Text(
                    'Stay on top of your work for today',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
