import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/clivora_colors.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/tool_grid_tile.dart';

/// Client tools hub, parity with freelancer Hub for collaboration surfaces.
class ClientHubScreen extends ConsumerWidget {
  const ClientHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlus = ref.watch(isProPlusProvider);

    return ClivoraScaffold(
      title: 'Client Hub',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 32),
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - t)),
                child: child,
              ),
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: ClivoraColors.clientGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your workspace',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'A command center for invoices, files, contracts, and updates from your freelancer.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _HubPill(icon: Icons.receipt_long_outlined, label: 'Pay'),
                      _HubPill(icon: Icons.folder_open_outlined, label: 'Review'),
                      _HubPill(icon: Icons.mail_outline, label: 'Reply'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _HubSectionHeader(
            title: 'Money',
            subtitle: 'Review balances, invoices, and payment records.',
          ),
          const SizedBox(height: 12),
          _ClientHubGrid(
            children: [
              ToolGridTile(
                icon: Icons.request_quote_outlined,
                label: 'Quotes',
                iconBackground: ClivoraColors.clientSurface,
                iconColor: ClivoraColors.clientAccent,
                onTap: () => context.push('/client-quotes'),
              ),
              ToolGridTile(
                icon: Icons.payments_outlined,
                label: 'Payments',
                iconBackground: ClivoraColors.iconGreen,
                iconColor: ClivoraColors.successGreen,
                onTap: () => context.push('/client-payments'),
              ),
              ToolGridTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Credits',
                iconBackground: ClivoraColors.iconYellow,
                iconColor: ClivoraColors.accent,
                onTap: () => context.push('/client-credits'),
              ),
              ToolGridTile(
                icon: Icons.autorenew,
                label: 'Recurring',
                iconBackground: ClivoraColors.clientSurface,
                iconColor: ClivoraColors.clientAccent,
                onTap: () => context.push('/client-recurring'),
              ),
              ToolGridTile(
                icon: Icons.receipt_long_outlined,
                label: 'Invoices',
                iconBackground: ClivoraColors.clientSurface,
                iconColor: ClivoraColors.clientAccent,
                onTap: () => context.go('/client-invoices'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _HubSectionHeader(
            title: 'Work together',
            subtitle: 'Find the latest files, decisions, and progress.',
          ),
          const SizedBox(height: 12),
          _ClientHubGrid(
            children: [
              ToolGridTile(
                icon: Icons.description_outlined,
                label: 'Contracts',
                iconBackground: ClivoraColors.clientSurface,
                iconColor: ClivoraColors.clientAccent,
                onTap: () => context.push('/client-contracts'),
              ),
              ToolGridTile(
                icon: Icons.add_task_outlined,
                label: 'Shared tasks',
                iconBackground: ClivoraColors.iconOrange,
                iconColor: ClivoraColors.warningOrange,
                onTap: () => context.push('/client-tasks'),
              ),
              ToolGridTile(
                icon: Icons.cloud_sync_outlined,
                label: 'Workspace tasks',
                iconBackground: ClivoraColors.iconBlue,
                iconColor: Colors.blue,
                onTap: () => context.push('/workspace-tasks'),
              ),
              ToolGridTile(
                icon: Icons.calendar_today_outlined,
                label: 'Calendar',
                iconBackground: ClivoraColors.iconGreen,
                iconColor: ClivoraColors.successGreen,
                onTap: () => context.push('/calendar'),
              ),
              ToolGridTile(
                icon: Icons.folder_open_outlined,
                label: 'Files',
                iconBackground: ClivoraColors.iconBlue,
                iconColor: Colors.blue,
                onTap: () => context.push('/client-files'),
              ),
              ToolGridTile(
                icon: Icons.timeline_outlined,
                label: 'Updates',
                iconBackground: ClivoraColors.clientSurface,
                iconColor: ClivoraColors.clientAccent,
                onTap: () => context.push('/client-activity'),
              ),
              ToolGridTile(
                icon: Icons.flag_outlined,
                label: 'Milestones',
                iconBackground: ClivoraColors.iconIndigo,
                iconColor: Colors.indigo,
                onTap: () => context.push('/client-milestones'),
              ),
              ToolGridTile(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Link freelancer',
                iconBackground: ClivoraColors.iconGreen,
                iconColor: ClivoraColors.successGreen,
                onTap: () => context.push('/client-link-freelancer'),
              ),
              if (isPlus)
                ToolGridTile(
                  icon: Icons.hub_outlined,
                  label: 'Connect',
                  iconBackground: ClivoraColors.clientSurface,
                  iconColor: ClivoraColors.clientAccent,
                  onTap: () => context.go('/connect'),
                )
            ],
          ),
          const SizedBox(height: 22),
          _HubSectionHeader(
            title: 'Growth & tools',
            subtitle: 'Campaigns, automation, AI, and sync - same suite as web.',
          ),
          const SizedBox(height: 12),
          _ClientHubGrid(
            children: [
              ToolGridTile(
                icon: Icons.account_tree_outlined,
                label: 'Automation',
                iconBackground: ClivoraColors.iconOrange,
                iconColor: ClivoraColors.warningOrange,
                onTap: () => context.push('/automation-builder'),
              ),
              ToolGridTile(
                icon: Icons.merge_type_outlined,
                label: 'CRM conflicts',
                iconBackground: ClivoraColors.iconRed,
                iconColor: Colors.redAccent,
                onTap: () => context.push('/crm-conflicts'),
              ),
              ToolGridTile(
                icon: Icons.sync_outlined,
                label: 'Sync Center',
                iconBackground: ClivoraColors.iconGreen,
                iconColor: ClivoraColors.successGreen,
                onTap: () => context.push('/sync-center'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientHubGrid extends StatelessWidget {
  const _ClientHubGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: children,
    );
  }
}

class _HubSectionHeader extends StatelessWidget {
  const _HubSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ClivoraColors.clientMuted),
          ),
        ],
      ),
    );
  }
}

class _HubPill extends StatelessWidget {
  const _HubPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
