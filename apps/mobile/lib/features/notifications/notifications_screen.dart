import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/user_roles.dart';
import '../../core/cloud/supabase_auth_helper.dart';
import '../../core/cloud/cloud_notification_repository.dart';
import '../../core/services/admin_management_service.dart';
import '../../core/services/team_invite_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloudAsync = ref.watch(cloudNotificationsProvider);
    final alertsAsync = ref.watch(notificationsProvider);
    final tasksAsync = ref.watch(freelancerClientTasksProvider);
    final mailboxAsync = ref.watch(freelancerMailboxProvider);
    final teamInvitesAsync = ref.watch(pendingTeamInvitesProvider);
    final isClient = isClientUser(ref.watch(authStateProvider).valueOrNull);

    return ClivoraScaffold(
      title: 'Notifications',
      showBackButton: true,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cloudNotificationsProvider);
          ref.invalidate(notificationsProvider);
          ref.invalidate(freelancerClientTasksProvider);
          ref.invalidate(clientAssignedTasksProvider);
          ref.invalidate(pendingTeamInvitesProvider);
          ref.invalidate(freelancerMailboxProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
          children: [
            cloudAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
              error: (e, _) => Text('Cloud notifications: $e'),
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptySection(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications',
                    subtitle: 'Invites and updates from CLIVORA appear here.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Inbox'),
                    const SizedBox(height: 8),
                    ...items.map((n) => _CloudNotificationCard(notification: n)),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            teamInvitesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (invites) {
                if (invites.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Team invites'),
                    const SizedBox(height: 8),
                    ...invites.map(
                      (invite) => _NotificationCard(
                        icon: Icons.groups_outlined,
                        iconColor: ClivoraColors.primary,
                        iconBg: ClivoraColors.primaryLight,
                        title: invite.projectName.isNotEmpty ? invite.projectName : 'Team invite',
                        subtitle: 'Tap to accept or decline',
                        onTap: () => context.push('/team-invites'),
                        trailing: const Icon(Icons.chevron_right, color: ClivoraColors.labelGray),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            if (!isClient)
              mailboxAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (messages) {
                  final unread = messages
                      .where((m) => !m.isRead && m.toUid == SupabaseAuthHelper.currentUid)
                      .take(5)
                      .toList();
                  if (unread.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Reminders'),
                      const SizedBox(height: 8),
                      _NotificationCard(
                        icon: Icons.mark_chat_unread_outlined,
                        iconColor: ClivoraColors.errorRed,
                        iconBg: ClivoraColors.iconRed,
                        title: '${unread.length} new message${unread.length == 1 ? '' : 's'}',
                        subtitle: 'You have unread client messages.',
                        onTap: () => context.push('/freelancer-messages'),
                        trailing: const Icon(Icons.chevron_right, color: ClivoraColors.labelGray),
                      ),
                      const SizedBox(height: 8),
                      ...unread.map(
                        (m) => _NotificationCard(
                          icon: Icons.mail_outline,
                          iconColor: ClivoraColors.navyDark,
                          iconBg: ClivoraColors.chipBackground,
                          title: m.fromEmail,
                          subtitle: m.body.length > 80 ? '${m.body.substring(0, 80)}…' : m.body,
                          onTap: () => context.push('/freelancer-messages'),
                          trailing: const Icon(Icons.chevron_right, color: ClivoraColors.labelGray),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            if (!isClient)
              tasksAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (tasks) {
                  if (tasks.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Client-assigned tasks'),
                      const SizedBox(height: 8),
                      ...tasks.map((t) => _ClientTaskCard(task: t, isFreelancer: true)),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            if (isClient)
              ref.watch(clientAssignedTasksProvider).when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (tasks) {
                      if (tasks.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Your assigned tasks'),
                          const SizedBox(height: 8),
                          ...tasks.map((t) => _ClientTaskCard(task: t, isFreelancer: false)),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
            alertsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (alerts) {
                if (alerts.isEmpty) return const SizedBox.shrink();
                final showHeader = mailboxAsync.maybeWhen(
                  data: (messages) {
                    final unread = messages
                        .where((m) => !m.isRead && m.toUid == SupabaseAuthHelper.currentUid)
                        .isEmpty;
                    return unread || isClient;
                  },
                  orElse: () => true,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showHeader) ...[
                      const _SectionTitle('Reminders'),
                      const SizedBox(height: 8),
                    ],
                    ...alerts.map(
                      (n) => _NotificationCard(
                        icon: n.type == NotificationType.task
                            ? Icons.task_alt
                            : Icons.receipt_long,
                        iconColor: n.priority <= 1
                            ? ClivoraColors.errorRed
                            : ClivoraColors.warningOrange,
                        iconBg: n.priority <= 1
                            ? ClivoraColors.iconRed
                            : ClivoraColors.iconOrange,
                        title: n.title,
                        subtitle: n.message,
                        onTap: () => context.push(n.route),
                        trailing: const Icon(Icons.chevron_right, color: ClivoraColors.labelGray),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.time,
    this.trailing,
    this.onDismiss,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String? time;
  final VoidCallback onTap;
  final Widget? trailing;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? ClivoraColors.darkBorder : ClivoraColors.borderLight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: ClivoraColors.textSecondary, height: 1.35),
                      ),
                      if (time != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          time!,
                          style: const TextStyle(fontSize: 11, color: ClivoraColors.labelGray),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onDismiss != null)
                  Material(
                    color: isDark ? ClivoraColors.darkBorder : ClivoraColors.chipBackground,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: onDismiss,
                      borderRadius: BorderRadius.circular(10),
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(Icons.close, size: 16, color: ClivoraColors.textSecondary),
                      ),
                    ),
                  )
                else ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CloudNotificationCard extends ConsumerWidget {
  const _CloudNotificationCard({required this.notification});

  final CloudNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = DateFormat('MMM d · h:mm a').format(notification.createdAt.toLocal());
    final style = _styleForKind(notification.kind);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: ClivoraColors.errorRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _dismiss(ref),
      child: _NotificationCard(
        icon: style.icon,
        iconColor: style.color,
        iconBg: style.bg,
        title: notification.title,
        subtitle: notification.body,
        time: time,
        onTap: () async {
          if (!notification.isRead) {
            await ref.read(cloudNotificationRepositoryProvider).markRead(notification.id);
          }
          ref.invalidate(cloudNotificationsProvider);
          ref.invalidate(unreadBadgeCountProvider);
          if (!context.mounted) return;
          final route = _routeForKind(notification.kind, ref);
          if (route != null) context.push(route);
        },
        onDismiss: () => _dismiss(ref),
      ),
    );
  }

  Future<void> _dismiss(WidgetRef ref) async {
    await ref.read(cloudNotificationRepositoryProvider).delete(notification.id);
    ref.invalidate(cloudNotificationsProvider);
    ref.invalidate(unreadBadgeCountProvider);
  }

  _KindStyle _styleForKind(String kind) {
    switch (kind) {
      case 'invite':
      case 'message':
        return const _KindStyle(Icons.mail_outline, ClivoraColors.navyDark, ClivoraColors.chipBackground);
      case 'task':
        return const _KindStyle(Icons.work_outline, ClivoraColors.primary, ClivoraColors.primaryLight);
      case 'invoice':
      case 'payment':
        return const _KindStyle(Icons.receipt_long_outlined, ClivoraColors.warningOrange, ClivoraColors.iconOrange);
      case 'project':
        return const _KindStyle(Icons.work_outline, ClivoraColors.primary, ClivoraColors.primaryLight);
      case 'contract':
        return const _KindStyle(Icons.description_outlined, ClivoraColors.navyDark, ClivoraColors.chipBackground);
      case 'team':
      case 'team_invite':
        return const _KindStyle(Icons.notifications_outlined, ClivoraColors.successGreen, ClivoraColors.iconGreen);
      default:
        return const _KindStyle(Icons.notifications_outlined, ClivoraColors.primary, ClivoraColors.primaryLight);
    }
  }

  String? _routeForKind(String kind, WidgetRef ref) {
    final isClient = isClientUser(ref.read(authStateProvider).valueOrNull);
    switch (kind) {
      case 'task':
        return isClient ? '/client-tasks' : '/notifications';
      case 'invoice':
      case 'payment':
        return isClient ? '/client-invoices' : '/invoices';
      case 'quote':
        return isClient ? '/client-quotes' : '/quotes';
      case 'project':
      case 'milestone':
        return isClient ? '/client-portal' : '/projects';
      case 'contract':
        return isClient ? '/client-contracts' : '/contracts';
      case 'invite':
      case 'message':
        return isClient ? '/client-messages' : '/freelancer-messages';
      case 'team_invite':
      case 'team':
        return '/team';
      case 'review':
        return '/reviews';
      default:
        return null;
    }
  }
}

class _KindStyle {
  const _KindStyle(this.icon, this.color, this.bg);
  final IconData icon;
  final Color color;
  final Color bg;
}

class _ClientTaskCard extends ConsumerWidget {
  const _ClientTaskCard({required this.task, required this.isFreelancer});

  final CloudClientTask task;
  final bool isFreelancer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(cloudClientTaskRepositoryProvider);
    final time = DateFormat('MMM d · h:mm a').format(task.createdAt.toLocal());

    return _NotificationCard(
      icon: Icons.assignment_outlined,
      iconColor: ClivoraColors.primary,
      iconBg: ClivoraColors.primaryLight,
      title: task.title,
      subtitle: task.description.isNotEmpty
          ? task.description
          : 'Status: ${task.status.replaceAll('_', ' ')}',
      time: time,
      onTap: () {},
      trailing: isFreelancer
          ? PopupMenuButton<String>(
              onSelected: (v) => repo.updateStatus(task.id, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'in_progress', child: Text('In progress')),
                PopupMenuItem(value: 'done', child: Text('Done')),
              ],
              child: Chip(
                label: Text(task.status.replaceAll('_', ' '), style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            )
          : TextButton(
              onPressed: () => repo.delete(task.id),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 56, color: ClivoraColors.labelGray.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
