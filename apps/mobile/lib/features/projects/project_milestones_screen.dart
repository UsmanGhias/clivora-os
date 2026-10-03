import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/milestone_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_format_helper.dart';
import '../../core/auth/auth_service.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/database_provider.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';

class ProjectMilestonesScreen extends ConsumerStatefulWidget {
  const ProjectMilestonesScreen({super.key, required this.projectId});

  final int projectId;

  @override
  ConsumerState<ProjectMilestonesScreen> createState() => _ProjectMilestonesScreenState();
}

class _ProjectMilestonesScreenState extends ConsumerState<ProjectMilestonesScreen> {
  Future<void> _addMilestone(Project project) async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New milestone'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title'), autofocus: true),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Amount (${project.currency})'),
              ),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Deliverable notes'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (titleCtrl.text.trim().isEmpty) return;
    await ref.read(milestoneServiceProvider).create(
          projectId: project.id,
          title: titleCtrl.text,
          description: descCtrl.text,
          amount: amount,
          currency: project.currency,
        );
  }

  @override
  Widget build(BuildContext context) {
    final ownerId = ref.watch(authStateProvider).valueOrNull?.id;
    final milestonesAsync = ref.watch(projectMilestonesProvider(widget.projectId));
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<Project?>(
      future: ownerId == null
          ? Future.value(null)
          : ref.read(databaseProvider).getProjectForUser(ownerId, widget.projectId),
      builder: (context, snap) {
        final project = snap.data;
        return ClivoraScaffold(
          title: 'Milestones',
          showBackButton: true,
          action: project == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addMilestone(project),
                ),
          body: project == null
              ? const EmptyState(icon: Icons.flag_outlined, message: 'Project not found')
              : milestonesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (milestones) {
                    if (milestones.isEmpty) {
                      return EmptyState(
                        icon: Icons.flag_outlined,
                        message: 'No milestones yet. Break ${project.name} into payment checkpoints.',
                        actionLabel: 'Add milestone',
                        onAction: () => _addMilestone(project),
                      );
                    }
              final total = milestones.fold<double>(0, (s, m) => s + m.amount);
              final approved = milestones.where((m) => m.status == MilestoneStatuses.approved || m.status == MilestoneStatuses.paid).fold<double>(0, (s, m) => s + m.amount);
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(project.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                Text(
                                  '${formatCurrency(approved, symbol: currencySymbol(project.currency))} approved of ${formatCurrency(total, symbol: currencySymbol(project.currency))}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: total <= 0 ? 0 : (approved / total).clamp(0.0, 1.0),
                                    minHeight: 8,
                                    backgroundColor: scheme.surfaceContainerHighest,
                                    color: ClivoraColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...milestones.map((m) => _MilestoneTile(
                              milestone: m,
                              onStatus: (status) => ref.read(milestoneServiceProvider).updateStatus(m, status),
                              onInvoice: () async {
                                final id = await ref.read(milestoneServiceProvider).createInvoiceFromMilestone(m);
                                if (!context.mounted || id == null) return;
                                context.push('/invoices/$id/edit');
                              },
                            )),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.milestone, required this.onStatus, required this.onInvoice});

  final ProjectMilestone milestone;
  final ValueChanged<String> onStatus;
  final VoidCallback onInvoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(milestone.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ClivoraColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(MilestoneStatuses.label(milestone.status), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ClivoraColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatCurrency(milestone.amount, symbol: currencySymbol(milestone.currency)),
              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
            ),
            if (milestone.dueDate != null)
              Text('Due ${formatDisplayDate(milestone.dueDate!)}', style: Theme.of(context).textTheme.bodySmall),
            if (milestone.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(milestone.description, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (milestone.status == MilestoneStatuses.pending)
                  OutlinedButton(onPressed: () => onStatus(MilestoneStatuses.inProgress), child: const Text('Start')),
                if (milestone.status == MilestoneStatuses.inProgress || milestone.status == MilestoneStatuses.pending)
                  FilledButton(onPressed: () => onStatus(MilestoneStatuses.submitted), child: const Text('Submit')),
                if (milestone.status == MilestoneStatuses.submitted)
                  FilledButton(onPressed: () => onStatus(MilestoneStatuses.approved), child: const Text('Approve')),
                if (milestone.invoiceId == null && milestone.status != MilestoneStatuses.canceled)
                  OutlinedButton.icon(onPressed: onInvoice, icon: const Icon(Icons.receipt_long, size: 18), label: const Text('Invoice')),
                if (milestone.status == MilestoneStatuses.approved)
                  TextButton(onPressed: () => onStatus(MilestoneStatuses.paid), child: const Text('Mark paid')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
