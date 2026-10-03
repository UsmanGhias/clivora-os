import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/user_roles.dart';
import '../../core/constants/plan_limits.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/greeting.dart';
import '../../core/utils/navigation_helper.dart';
import '../../core/services/coach_marks_service.dart';
import '../../core/services/email_verification_service.dart';
import '../../core/services/admin_management_service.dart';
import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/clivora_logo.dart';
import '../../shared/widgets/simple_coach_tour.dart';
import '../../shared/widgets/messages_icon_button.dart';
import '../../shared/widgets/notification_icon_button.dart';
import '../../shared/widgets/skeleton_loading.dart';
import '../../shared/widgets/today_overdue_card.dart';
import 'priority_strips.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowCoachMarks());
  }

  Future<void> _maybeShowCoachMarks() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || isClientUser(user)) return;
    final show = await ref.read(coachMarksServiceProvider).shouldShowForRole(isClient: false);
    if (!show || !mounted) return;
    try {
      await ref.read(dashboardStatsProvider.future);
    } catch (_) {}
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    await showSimpleCoachTour(
      context,
      steps: [
        SimpleCoachStep(
          icon: Icons.insights_outlined,
          title: l10n.coachMarkStatsTitle,
          body: l10n.coachMarkStatsBody,
        ),
        SimpleCoachStep(
          icon: Icons.bolt_outlined,
          title: l10n.coachMarkQuickTitle,
          body: l10n.coachMarkQuickBody,
        ),
        SimpleCoachStep(
          icon: Icons.search_rounded,
          title: l10n.coachMarkSearchTitle,
          body: l10n.coachMarkSearchBody,
        ),
      ],
      onComplete: () => ref.read(coachMarksServiceProvider).markDashboardCompleteForRole(isClient: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(dashboardStatsProvider);
    final profileAsync = ref.watch(businessProfileProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final projectsAsync = ref.watch(projectsProvider(const ProjectFilter(status: 'in_progress')));
    final customersAsync = ref.watch(customersProvider(null));
    final isPlus = ref.watch(isProPlusProvider);
    final isPro = ref.watch(isProProvider);
    final unreadAsync = ref.watch(unreadMessagesProvider);

    final ownerName = authUser?.name.isNotEmpty == true
        ? authUser!.name.split(' ').first
        : profileAsync.maybeWhen(
            data: (p) => p.ownerName.isNotEmpty ? p.ownerName.split(' ').first : 'there',
            orElse: () => 'there',
          );
    final photoPath = authUser?.profilePhotoPath ?? profileAsync.valueOrNull?.ownerPhotoPath;
    final isGuest = isGuestUser(authUser);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider);
            ref.invalidate(projectsProvider);
            ref.invalidate(customersProvider);
            ref.invalidate(notificationsProvider);
            ref.invalidate(cloudNotificationsProvider);
            ref.invalidate(unreadMessagesProvider);
            ref.invalidate(revenueSparklineProvider);
          },
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              if (isGuest)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ClivoraColors.navyDark.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'GUEST PREVIEW · FREELANCER',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                  ),
                ),
              _DashboardHeader(
                ownerName: ownerName,
                photoPath: photoPath,
                isPro: isPro,
                isPlus: isPlus,
                onProfile: () => openFormRoute(context, '/profile'),
              ),
              if (authUser != null &&
                  !isGuestUser(authUser) &&
                  !ref.watch(emailVerificationServiceProvider).isVerified(authUser)) ...[
                const SizedBox(height: 12),
                Material(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => openFormRoute(context, '/profile'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.mark_email_unread_outlined, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Verify your email to create clients, invoices, and projects. Tap to open Profile.',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Command center: agenda + Connect queue first (research: trust & retention)
              const FreelancerPriorityStrip(),
              const SizedBox(height: 8),
              const TodayOverdueCard(),
              const SizedBox(height: 12),
              statsAsync.when(
                loading: () => const StatsGridSkeleton(),
                error: (_, _) => const SizedBox.shrink(),
                data: (stats) => _ProfileCompletenessCard(stats: stats, profile: profileAsync.valueOrNull),
              ),
              const SizedBox(height: 14),
              statsAsync.when(
                loading: () => const StatsGridSkeleton(),
                error: (_, _) => const StatsGridSkeleton(),
                data: (stats) => _KpiGrid(
                  stats: stats,
                  unread: unreadAsync.valueOrNull ?? 0,
                  onNavigate: context.go,
                ),
              ),
              const SizedBox(height: 12),
              statsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (stats) => _SuccessScoreCard(stats: stats),
              ),
              const SizedBox(height: 12),
              const _EarningsOverviewCard(),
              const SizedBox(height: 12),
              // Secondary 2x2 removed - KPI grid above already covers earnings / projects / customers
              _QuickActions(ref: ref, l10n: l10n),
              const SizedBox(height: 14),
              _SearchBar(onTap: () => openFormRoute(context, '/search')),
              const SizedBox(height: 20),
              _GetStartedCard(ref: ref),
              const SizedBox(height: 8),
              _SectionHeader(
                title: 'Active Projects',
                onViewAll: () => context.go('/projects'),
              ),
              const SizedBox(height: 10),
              projectsAsync.when(
                loading: () => const CardSkeleton(height: 72),
                error: (_, _) => const SizedBox.shrink(),
                data: (projects) {
                  final active = projects.where((p) => p.status == 'in_progress').take(3).toList();
                  if (active.isEmpty) {
                    return _EmptySectionCard(
                      icon: Icons.work_outline,
                      message: 'No active projects',
                      actionLabel: 'Create Project',
                      onAction: () => tryOpenWithPlanCheck(
                        context,
                        ref: ref,
                        canAdd: () => ref.read(planLimitServiceProvider).canAddProject(),
                        path: '/projects/new',
                        resource: 'projects',
                        max: PlanLimits.freeMaxProjects,
                      ),
                    );
                  }
                  return Column(
                    children: active
                        .map(
                          (p) => _ProjectTile(
                            name: p.name,
                            status: p.status,
                            onTap: () => openFormRoute(context, '/projects/${p.id}/edit'),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: 'Recent Customers',
                onViewAll: () => context.go('/customers'),
              ),
              const SizedBox(height: 10),
              customersAsync.when(
                loading: () => const CardSkeleton(height: 72),
                error: (_, _) => const SizedBox.shrink(),
                data: (customers) {
                  if (customers.isEmpty) {
                    return _EmptySectionCard(
                      icon: Icons.people_outline,
                      message: 'No customers yet',
                      actionLabel: 'Add Customer',
                      onAction: () => tryOpenWithPlanCheck(
                        context,
                        ref: ref,
                        canAdd: () => ref.read(planLimitServiceProvider).canAddCustomer(),
                        path: '/customers/new',
                        resource: 'clients',
                        max: PlanLimits.freeMaxClients,
                      ),
                    );
                  }
                  return Column(
                    children: customers
                        .take(3)
                        .map(
                          (c) => _CustomerTile(
                            name: c.contactPerson,
                            company: c.company,
                            onTap: () => openFormRoute(context, '/customers/${c.id}/edit'),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.ownerName,
    required this.photoPath,
    required this.isPro,
    required this.isPlus,
    required this.onProfile,
  });

  final String ownerName;
  final String? photoPath;
  final bool isPro;
  final bool isPlus;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileAvatar(
          photoPath: photoPath,
          name: ownerName,
          radius: 24,
          showVerified: isPro,
          onTap: onProfile,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${timeBasedGreeting()}, $ownerName ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ClivoraColors.textPrimary,
                      ),
                    ),
                    const TextSpan(text: '👋', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (isPlus || isPro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ClivoraColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.diamond_outlined,
                        size: 14,
                        color: ClivoraColors.primaryDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPlus ? 'Pro Plus' : 'Pro',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: ClivoraColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const MessagesIconButton(route: '/freelancer-messages'),
        const SizedBox(width: 8),
        const NotificationIconButton(isClient: false),
      ],
    );
  }
}

class _ProfileCompletenessCard extends StatelessWidget {
  const _ProfileCompletenessCard({required this.stats, this.profile});

  final DashboardStats stats;
  final BusinessProfile? profile;

  int get _score {
    var s = 0;
    if ((profile?.ownerName ?? '').trim().isNotEmpty) s += 20;
    if ((profile?.businessEmail ?? '').trim().isNotEmpty) s += 20;
    if ((profile?.businessPhone ?? '').trim().isNotEmpty) s += 15;
    if ((profile?.bio ?? '').trim().isNotEmpty) s += 15;
    if ((profile?.businessAddress ?? '').trim().isNotEmpty) s += 10;
    if (stats.customers > 0) s += 10;
    if (stats.activeProjects > 0) s += 10;
    return s.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final pct = _score;
    final done = pct >= 100;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ClivoraColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: ClivoraColors.navyDark.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Completeness',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pct%',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ClivoraColors.textPrimary),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 8,
                    backgroundColor: ClivoraColors.primaryLight,
                    color: ClivoraColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      done ? Icons.check_circle : Icons.info_outline,
                      size: 16,
                      color: done ? ClivoraColors.successGreen : ClivoraColors.warningOrange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        done ? 'Great job! You\'re all set.' : 'Complete your profile to win more work.',
                        style: const TextStyle(fontSize: 12, color: ClivoraColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ClivoraColors.primary,
                  ClivoraColors.primaryDark,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: ClivoraColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.stats,
    required this.unread,
    required this.onNavigate,
  });

  final DashboardStats stats;
  final int unread;
  final void Function(String) onNavigate;

  @override
  Widget build(BuildContext context) {
    final earnings = stats.revenue > 0 ? stats.revenue : stats.totalInvoiced;
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            title: 'Invoiced',
            value: formatCurrency(earnings),
            subtitle: stats.outstanding > 0
                ? '${formatCurrency(stats.outstanding)} due'
                : (stats.revenue > 0 ? 'Paid' : 'Total billed'),
            icon: Icons.account_balance_wallet_outlined,
            iconBg: ClivoraColors.iconGreen,
            iconColor: ClivoraColors.successGreen,
            sparkColor: ClivoraColors.primary,
            onTap: () => onNavigate('/invoices'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            title: 'Customers',
            value: '${stats.customers}',
            subtitle: '${stats.activeProjects} active',
            icon: Icons.people_outline,
            iconBg: ClivoraColors.iconOrange,
            iconColor: ClivoraColors.warningOrange,
            sparkColor: ClivoraColors.warningOrange,
            onTap: () => onNavigate('/customers'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            title: 'Messages',
            value: '$unread',
            subtitle: 'Unread',
            icon: Icons.chat_bubble_outline,
            iconBg: ClivoraColors.iconBlue,
            iconColor: Colors.blue,
            sparkColor: Colors.blue,
            onTap: () => onNavigate('/freelancer-messages'),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.sparkColor,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color sparkColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ClivoraColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 11, color: ClivoraColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ClivoraColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: ClivoraColors.successGreen, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              SizedBox(
                height: 28,
                width: double.infinity,
                child: CustomPaint(painter: _MiniSparkPainter(color: sparkColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSparkPainter extends CustomPainter {
  _MiniSparkPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final points = [0.15, 0.45, 0.28, 0.7, 0.4, 0.55, 0.85];
    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SuccessScoreCard extends StatelessWidget {
  const _SuccessScoreCard({required this.stats});

  final DashboardStats stats;

  int get _score {
    var s = 70;
    if (stats.customers > 0) s += 8;
    if (stats.activeProjects > 0) s += 8;
    if (stats.revenue > 0) s += 10;
    if (stats.outstanding == 0 && stats.totalInvoiced > 0) s += 4;
    return s.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ClivoraColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ClivoraColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.star_rounded, color: ClivoraColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Success Score', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const Spacer(),
                    Text('$score%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 14, color: ClivoraColors.primaryDark),
                    const SizedBox(width: 4),
                    Text(
                      score >= 90 ? 'Top Rated' : 'Growing',
                      style: const TextStyle(fontSize: 12, color: ClivoraColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 6,
                    backgroundColor: ClivoraColors.primaryLight,
                    color: ClivoraColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsOverviewCard extends ConsumerWidget {
  const _EarningsOverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(revenueSparklineProvider);
    final stats = ref.watch(dashboardStatsProvider).valueOrNull;
    final total = stats?.revenue ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ClivoraColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Earnings Overview', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ClivoraColors.chipBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('This Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatCurrency(total),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Paid revenue · last 30 days',
            style: TextStyle(fontSize: 12, color: ClivoraColors.successGreen, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          seriesAsync.when(
            loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, _) => const SizedBox.shrink(),
            data: (series) {
              final max = series.fold<double>(0, (m, v) => v > m ? v : m);
              return SizedBox(
                height: 140,
                child: CustomPaint(
                  size: const Size(double.infinity, 140),
                  painter: _EarningsChartPainter(
                    series: series,
                    maxY: max <= 0 ? 1 : max,
                    color: ClivoraColors.primary,
                  ),
                  child: max <= 0
                      ? const Center(
                          child: Text(
                            'No paid earnings yet',
                            style: TextStyle(color: ClivoraColors.textSecondary, fontSize: 13),
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EarningsChartPainter extends CustomPainter {
  _EarningsChartPainter({
    required this.series,
    required this.maxY,
    required this.color,
  });

  final List<double> series;
  final double maxY;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final grid = Paint()
      ..color = ClivoraColors.borderLight
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final path = Path();
    final prev = Path();
    for (var i = 0; i < series.length; i++) {
      final x = size.width * (i / math.max(1, series.length - 1));
      final y = size.height * (1 - (series[i] / maxY).clamp(0.0, 1.0));
      final py = size.height * (1 - ((series[i] * 0.82) / maxY).clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
        prev.moveTo(x, py);
      } else {
        path.lineTo(x, y);
        prev.lineTo(x, py);
      }
    }

    final prevPaint = Paint()
      ..color = ClivoraColors.labelGray.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // dashed previous month
    final dashPath = Path();
    for (final metric in prev.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 6, metric.length);
        dashPath.addPath(metric.extractPath(distance, next), Offset.zero);
        distance += 10;
      }
    }
    canvas.drawPath(dashPath, prevPaint);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fill);

    final dot = Paint()..color = color;
    final lastX = size.width;
    final lastY = size.height * (1 - (series.last / maxY).clamp(0.0, 1.0));
    canvas.drawCircle(Offset(lastX, lastY), 4, dot);
  }

  @override
  bool shouldRepaint(covariant _EarningsChartPainter oldDelegate) =>
      oldDelegate.series != series || oldDelegate.maxY != maxY;
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.ref, required this.l10n});

  final WidgetRef ref;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    Future<void> addCustomer() => tryOpenWithPlanCheck(
          context,
          ref: ref,
          canAdd: () => ref.read(planLimitServiceProvider).canAddCustomer(),
          path: '/customers/new',
          resource: 'clients',
          max: PlanLimits.freeMaxClients,
        );
    Future<void> addProject() => tryOpenWithPlanCheck(
          context,
          ref: ref,
          canAdd: () => ref.read(planLimitServiceProvider).canAddProject(),
          path: '/projects/new',
          resource: 'projects',
          max: PlanLimits.freeMaxProjects,
        );
    Future<void> addInvoice() => tryOpenWithPlanCheck(
          context,
          ref: ref,
          canAdd: () => ref.read(planLimitServiceProvider).canAddInvoice(),
          path: '/invoices/new',
          resource: 'invoices this month',
          max: PlanLimits.freeMaxInvoicesPerMonth,
        );

    final actions = [
      _QuickAction(Icons.person_add_outlined, l10n.quickActionClient, ClivoraColors.iconTeal, ClivoraColors.primary, () => addCustomer()),
      _QuickAction(Icons.create_new_folder_outlined, l10n.quickActionProject, ClivoraColors.iconOrange, ClivoraColors.warningOrange, () => addProject()),
      _QuickAction(Icons.receipt_long_outlined, l10n.quickActionInvoice, ClivoraColors.iconGreen, ClivoraColors.successGreen, () => addInvoice()),
      _QuickAction(Icons.task_alt_outlined, l10n.quickActionTask, ClivoraColors.iconBlue, Colors.blue, () async {
        if (!await requireEmailVerified(context, ref, actionLabel: 'create tasks')) return;
        if (context.mounted) openFormRoute(context, '/tasks/new');
      }),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: actions.map((a) {
        return GestureDetector(
          onTap: a.onTap,
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: a.bg, borderRadius: BorderRadius.circular(16)),
                child: Icon(a.icon, color: a.color),
              ),
              const SizedBox(height: 8),
              Text(a.label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.icon, this.label, this.bg, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color bg;
  final Color color;
  final VoidCallback onTap;
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: ClivoraColors.primary.withValues(alpha: 0.45), width: 1.5),
          ),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: ClivoraColors.primary, size: 22),
              SizedBox(width: 10),
              Text(
                'Search workspace',
                style: TextStyle(color: ClivoraColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onViewAll});
  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        TextButton(
          onPressed: onViewAll,
          child: const Text('View all >', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _GetStartedCard extends ConsumerWidget {
  const _GetStartedCard({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final stats = ref.watch(dashboardStatsProvider).valueOrNull;
    if (stats != null && stats.customers > 0 && stats.activeProjects > 0) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ClivoraColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Get started', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Complete these steps to set up your workspace.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          _ChecklistItem(Icons.person_outline, ClivoraColors.primary, 'Add client', () {
            tryOpenWithPlanCheck(
              context,
              ref: ref,
              canAdd: () => ref.read(planLimitServiceProvider).canAddCustomer(),
              path: '/customers/new',
              resource: 'clients',
              max: PlanLimits.freeMaxClients,
            );
          }),
          _ChecklistItem(Icons.folder_outlined, ClivoraColors.warningOrange, 'Create a project', () {
            tryOpenWithPlanCheck(
              context,
              ref: ref,
              canAdd: () => ref.read(planLimitServiceProvider).canAddProject(),
              path: '/projects/new',
              resource: 'projects',
              max: PlanLimits.freeMaxProjects,
            );
          }),
          _ChecklistItem(Icons.receipt_long_outlined, ClivoraColors.successGreen, 'Send invoice', () {
            tryOpenWithPlanCheck(
              context,
              ref: ref,
              canAdd: () => ref.read(planLimitServiceProvider).canAddInvoice(),
              path: '/invoices/new',
              resource: 'invoices this month',
              max: PlanLimits.freeMaxInvoicesPerMonth,
            );
          }),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.icon, this.color, this.label, this.onTap);

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            const Icon(Icons.chevron_right, color: ClivoraColors.labelGray),
          ],
        ),
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ClivoraColors.borderLight),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: ClivoraColors.labelGray),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ClivoraColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add, size: 18, color: ClivoraColors.primary),
            label: Text(actionLabel, style: const TextStyle(color: ClivoraColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.name, required this.status, required this.onTap});
  final String name;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClivoraColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ClivoraColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.work_outline, color: ClivoraColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      status == 'in_progress' ? 'In Progress' : status,
                      style: const TextStyle(fontSize: 12, color: ClivoraColors.successGreen, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: ClivoraColors.labelGray),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.name, required this.company, required this.onTap});
  final String name;
  final String company;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClivoraColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ClivoraColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_outline, color: ClivoraColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (company.isNotEmpty)
                      Text(company, style: const TextStyle(fontSize: 12, color: ClivoraColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: ClivoraColors.labelGray),
            ],
          ),
        ),
      ),
    );
  }
}
