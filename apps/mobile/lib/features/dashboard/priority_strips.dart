import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/marketplace/connect_marketplace_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../data/providers/app_providers.dart';

/// Action-first Connect / work summary strip for freelancer home (teal branding).
class FreelancerPriorityStrip extends ConsumerStatefulWidget {
  const FreelancerPriorityStrip({super.key});

  @override
  ConsumerState<FreelancerPriorityStrip> createState() => _FreelancerPriorityStripState();
}

class _FreelancerPriorityStripState extends ConsumerState<FreelancerPriorityStrip> {
  Map<String, dynamic> _home = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!ref.read(isProPlusProvider)) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    try {
      final data = await ref.read(connectMarketplaceServiceProvider).homeSummary(client: false);
      if (!mounted) return;
      setState(() {
        _home = data;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 8);
    final isPlus = ref.watch(isProPlusProvider);
    final pending = (_home['pending_proposals'] as num?)?.toInt() ?? 0;
    final accepted = (_home['accepted_proposals'] as num?)?.toInt() ?? 0;
    final milestones = (_home['active_milestones'] as num?)?.toInt() ?? 0;
    final unread = (_home['unread_messages'] as num?)?.toInt() ?? 0;
    if (pending + accepted + milestones + unread == 0 && !isPlus) {
      return const SizedBox.shrink();
    }
    final action = _freelancerAction(pending: pending, accepted: accepted, milestones: milestones, unread: unread);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _PriorityCard(
        color: ClivoraColors.primary,
        title: 'Work queue',
        subtitle: action.subtitle,
        icon: Icons.bolt_outlined,
        actionLabel: action.label,
        actionIcon: action.icon,
        onAction: () => context.push(action.route),
        metrics: [
          _PriorityMetricData('Proposals', pending),
          _PriorityMetricData('Accepted', accepted),
          _PriorityMetricData('Unread', unread),
        ],
      ),
    );
  }

  _PriorityAction _freelancerAction({
    required int pending,
    required int accepted,
    required int milestones,
    required int unread,
  }) {
    if (unread > 0) {
      return _PriorityAction(
        label: 'Reply to messages',
        subtitle: '$unread client ${unread == 1 ? 'message needs' : 'messages need'} a response.',
        route: '/freelancer-messages',
        icon: Icons.chat_bubble_outline,
      );
    }
    if (accepted + milestones > 0) {
      return const _PriorityAction(
        label: 'Review Connect work',
        subtitle: 'Keep accepted work and milestones moving from one place.',
        route: '/connect',
        icon: Icons.check_circle_outline,
      );
    }
    if (pending > 0) {
      return _PriorityAction(
        label: 'Track proposals',
        subtitle: '$pending ${pending == 1 ? 'proposal is' : 'proposals are'} waiting for client action.',
        route: '/connect',
        icon: Icons.outbox_outlined,
      );
    }
    return const _PriorityAction(
      label: 'Find your next project',
      subtitle: 'Browse Connect opportunities and send a focused proposal.',
      route: '/connect',
      icon: Icons.search_outlined,
    );
  }
}

/// Action-first summary for client home (slate branding).
class ClientPriorityStrip extends ConsumerStatefulWidget {
  const ClientPriorityStrip({super.key});

  @override
  ConsumerState<ClientPriorityStrip> createState() => _ClientPriorityStripState();
}

class _ClientPriorityStripState extends ConsumerState<ClientPriorityStrip> {
  Map<String, dynamic> _home = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(connectMarketplaceServiceProvider).homeSummary(client: true);
      if (!mounted) return;
      setState(() {
        _home = data;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final isPlus = ref.watch(isProPlusProvider);
    final jobs = (_home['open_jobs'] as num?)?.toInt() ?? 0;
    final pending = (_home['pending_proposals'] as num?)?.toInt() ?? 0;
    final milestones = (_home['milestones_needing_action'] as num?)?.toInt() ?? 0;
    final unread = (_home['unread_messages'] as num?)?.toInt() ?? 0;
    final action = _clientAction(jobs: jobs, pending: pending, milestones: milestones, unread: unread, isPlus: isPlus);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _PriorityCard(
        color: ClivoraColors.clientAccent,
        title: 'Client actions',
        subtitle: action.subtitle,
        icon: Icons.assignment_outlined,
        actionLabel: action.label,
        actionIcon: action.icon,
        actionForeground: ClivoraColors.clientAccent,
        onAction: () => context.push(action.route),
        metrics: [
          _PriorityMetricData('Open jobs', jobs),
          _PriorityMetricData('Proposals', pending),
          _PriorityMetricData('Approvals', milestones),
          _PriorityMetricData('Unread', unread),
        ],
      ),
    );
  }

  _PriorityAction _clientAction({
    required int jobs,
    required int pending,
    required int milestones,
    required int unread,
    required bool isPlus,
  }) {
    if (milestones > 0) {
      return _PriorityAction(
        label: 'Review approvals',
        subtitle: '$milestones ${milestones == 1 ? 'milestone is' : 'milestones are'} ready for your review.',
        route: '/connect',
        icon: Icons.fact_check_outlined,
      );
    }
    if (unread > 0) {
      return _PriorityAction(
        label: 'Open messages',
        subtitle: '$unread freelancer ${unread == 1 ? 'message is' : 'messages are'} waiting.',
        route: '/client-messages',
        icon: Icons.mail_outline,
      );
    }
    if (pending > 0) {
      return _PriorityAction(
        label: 'Compare proposals',
        subtitle: '$pending ${pending == 1 ? 'proposal is' : 'proposals are'} ready to review.',
        route: '/connect',
        icon: Icons.rate_review_outlined,
      );
    }
    if (isPlus && jobs == 0) {
      return const _PriorityAction(
        label: 'Post a job',
        subtitle: 'Share a need on Connect and start collecting proposals.',
        route: '/connect/need',
        icon: Icons.add_circle_outline,
      );
    }
    return const _PriorityAction(
      label: 'Open Connect',
      subtitle: 'Review jobs, proposals, and collaboration requests.',
      route: '/connect',
      icon: Icons.hub_outlined,
    );
  }
}

class _PriorityAction {
  const _PriorityAction({
    required this.label,
    required this.subtitle,
    required this.route,
    required this.icon,
  });

  final String label;
  final String subtitle;
  final String route;
  final IconData icon;
}

class _PriorityMetricData {
  const _PriorityMetricData(this.label, this.value);

  final String label;
  final int value;
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.metrics,
    this.actionForeground,
  });

  final Color color;
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final List<_PriorityMetricData> metrics;
  final Color? actionForeground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), height: 1.35, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PriorityMetricsRow(metrics: metrics),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon, size: 18),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: actionForeground ?? color,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width metric layout: 3 → one row; 4 → 2×2. No leftover empty gaps.
class _PriorityMetricsRow extends StatelessWidget {
  const _PriorityMetricsRow({required this.metrics});

  final List<_PriorityMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.length == 4) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _PriorityMetric(label: metrics[0].label, value: metrics[0].value)),
              const SizedBox(width: 8),
              Expanded(child: _PriorityMetric(label: metrics[1].label, value: metrics[1].value)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _PriorityMetric(label: metrics[2].label, value: metrics[2].value)),
              const SizedBox(width: 8),
              Expanded(child: _PriorityMetric(label: metrics[3].label, value: metrics[3].value)),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _PriorityMetric(label: metrics[i].label, value: metrics[i].value)),
        ],
      ],
    );
  }
}

class _PriorityMetric extends StatelessWidget {
  const _PriorityMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
