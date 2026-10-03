import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/constants/invoice_statuses.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';

/// Business metrics dashboard for freelancers.
class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = ref.watch(authStateProvider).valueOrNull?.id;
    if (ownerId == null) {
      return const ClivoraScaffold(title: 'Analytics', showBackButton: true, body: Center(child: Text('Sign in to view analytics')));
    }

    final isPro = ref.watch(isProProvider);
    final invoicesAsync = ref.watch(invoicesProvider(null));
    final customersAsync = ref.watch(customersProvider(null));
    final projectsAsync = ref.watch(projectsProvider(const ProjectFilter()));
    final tasksAsync = ref.watch(tasksProvider(const TaskFilter()));

    return ClivoraScaffold(
      title: 'Analytics',
      showBackButton: true,
      body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              invoicesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (invoices) {
                  final paid = invoices.where((i) => i.status == InvoiceStatuses.paid);
                  final overdue = invoices.where((i) => i.status == InvoiceStatuses.overdue);
                  final outstanding = invoices.where((i) => InvoiceStatuses.outstanding.contains(i.status));
                  final revenue = paid.fold<double>(0, (s, i) => s + i.total);
                  final overdueTotal = overdue.fold<double>(0, (s, i) => s + i.total);
                  final outstandingTotal = outstanding.fold<double>(0, (s, i) => s + i.total);

                  final customers = customersAsync.valueOrNull ?? [];
                  final projects = projectsAsync.valueOrNull ?? [];
                  final tasks = tasksAsync.valueOrNull ?? [];
                  final completedProjects = projects.where((p) => p.status == 'completed').length;
                  final completedTasks = tasks.where((t) => t.completed).length;
                  final completionRate = projects.isEmpty ? 0.0 : completedProjects / projects.length;
                  final taskRate = tasks.isEmpty ? 0.0 : completedTasks / tasks.length;

                  final barData = [
                    _BarEntry('Paid', revenue, ClivoraColors.successGreen),
                    _BarEntry('Outstanding', outstandingTotal, Colors.orange),
                    _BarEntry('Overdue', overdueTotal, Colors.red),
                  ];
                  final maxBar = barData.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MetricCard(label: 'Revenue (paid)', value: formatCurrency(revenue), color: ClivoraColors.successGreen),
                      const SizedBox(height: 12),
                      _MetricCard(label: 'Outstanding', value: formatCurrency(outstandingTotal), color: Colors.orange),
                      const SizedBox(height: 12),
                      _MetricCard(label: 'Overdue', value: formatCurrency(overdueTotal), color: Colors.red),
                      const SizedBox(height: 12),
                      _MetricCard(label: 'Active clients', value: '${customers.length}', color: ClivoraColors.primary),
                      const SizedBox(height: 20),
                      Text('Revenue overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _SimpleBarChart(data: barData, maxValue: maxBar <= 0 ? 1 : maxBar),
                      const SizedBox(height: 20),
                      Text('Performance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _MetricRow(label: 'Project completion rate', value: '${(completionRate * 100).toStringAsFixed(0)}%'),
                      _MetricRow(label: 'Task completion rate', value: '${(taskRate * 100).toStringAsFixed(0)}%'),
                      _MetricRow(label: 'Total invoices', value: '${invoices.length}'),
                      _MetricRow(label: 'Paid invoices', value: '${paid.length}'),
                      _MetricRow(label: 'Overdue invoices', value: '${overdue.length}'),
                      const SizedBox(height: 20),
                      Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Advanced trends', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              _AdvancedTrendsChart(
                                paidCount: paid.length,
                                overdueCount: overdue.length,
                                projectRate: completionRate,
                                taskRate: taskRate,
                              ),
                            ],
                          ),
                          if (!isPro)
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.82),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.lock_outline, size: 32, color: ClivoraColors.primary),
                                      const SizedBox(height: 12),
                                      const Text('Advanced analytics', style: TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Unlock trend charts, forecasts, and deeper insights with Pro.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton(
                                        onPressed: () => context.push('/upgrade'),
                                        child: const Text('Upgrade to Pro'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
    );
  }
}

class _BarEntry {
  const _BarEntry(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class _SimpleBarChart extends StatelessWidget {
  const _SimpleBarChart({required this.data, required this.maxValue});

  final List<_BarEntry> data;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final entry in data)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        entry.value > 0 ? formatCurrency(entry.value) : 'N/A',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: 90 * (entry.value / maxValue).clamp(0.05, 1.0),
                        decoration: BoxDecoration(
                          color: entry.color.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.label,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedTrendsChart extends StatelessWidget {
  const _AdvancedTrendsChart({
    required this.paidCount,
    required this.overdueCount,
    required this.projectRate,
    required this.taskRate,
  });

  final int paidCount;
  final int overdueCount;
  final double projectRate;
  final double taskRate;

  @override
  Widget build(BuildContext context) {
    final points = [
      paidCount.toDouble(),
      overdueCount.toDouble(),
      projectRate * 100,
      taskRate * 100,
    ];
    final max = points.fold<double>(0, (a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: SizedBox(
        height: 140,
        child: CustomPaint(
          painter: _LineChartPainter(values: points, maxValue: max),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                Text('Paid', style: TextStyle(fontSize: 10)),
                Text('Overdue', style: TextStyle(fontSize: 10)),
                Text('Projects', style: TextStyle(fontSize: 10)),
                Text('Tasks', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values, required this.maxValue});

  final List<double> values;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = ClivoraColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fill = Paint()
      ..color = ClivoraColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final stepX = size.width / (values.length - 1).clamp(1, values.length);
    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxValue) * (size.height - 16);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo((values.length - 1) * stepX, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, paint);

    final dot = Paint()..color = ClivoraColors.primary;
    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxValue) * (size.height - 16);
      canvas.drawCircle(Offset(x, y), 4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.maxValue != maxValue;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.insights, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
