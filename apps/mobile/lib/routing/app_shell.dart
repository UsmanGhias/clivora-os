import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_service.dart';
import '../core/auth/user_roles.dart';
import '../core/services/marketplace/connect_marketplace_service.dart';
import '../core/theme/clivora_tokens.dart';
import '../core/theme/theme_context.dart';
import '../core/utils/exit_dialog.dart';
import '../data/providers/app_providers.dart';
import '../shared/widgets/offline_status_bar.dart';
import '../shared/widgets/sync_failure_banner.dart';

/// Pending Connect inbox count for Pro Plus bottom-nav badge.
final connectPendingBadgeProvider = FutureProvider<int>((ref) async {
  ref.watch(authStateProvider);
  // Connect is Pro Plus only for both freelancers and clients.
  final allowed = ref.watch(isProPlusProvider);
  if (!allowed) return 0;
  try {
    final rows = await ref.read(connectMarketplaceServiceProvider).myRequests();
    final uid = ref.read(connectMarketplaceServiceProvider).currentUserId;
    return rows.where((r) => r['status'] == 'pending' && r['to_user_id'] == uid).length;
  } catch (_) {
    return 0;
  }
});

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  /// CRM mockup: Home · Clients · Hub · Billing · More
  /// Hub icon = network hub (same as v3.9.6 / preferred 4.2.x).
  static const _freelancerBaseTabs = [
    _NavItem('/dashboard', Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem('/customers', Icons.groups_outlined, Icons.groups, 'Clients'),
    _NavItem('/connect', Icons.travel_explore_outlined, Icons.travel_explore, 'Connect', connectBadge: true),
    _NavItem('/invoices', Icons.receipt_long_outlined, Icons.receipt_long, 'Billing'),
    _NavItem('/more', Icons.hub_outlined, Icons.hub, 'Hub'),
  ];

  /// Pro Plus: Connect uses v3.9.6 travel_explore logo (both roles).
  static const _freelancerPlusTabs = [
    _NavItem('/dashboard', Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem('/customers', Icons.groups_outlined, Icons.groups, 'Clients'),
    _NavItem('/connect', Icons.travel_explore_outlined, Icons.travel_explore, 'Connect', connectBadge: true),
    _NavItem('/invoices', Icons.receipt_long_outlined, Icons.receipt_long, 'Billing'),
    _NavItem('/more', Icons.hub_outlined, Icons.hub, 'Hub'),
  ];

  /// Free client: keep Account (profile/login) on the bar. Hub lives inside Account.
  /// Icons aligned with web AppShell (chat≈MessageSquare, travel_explore≈Compass Connect).
  static const _clientBaseTabs = [
    _NavItem('/client-portal', Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem('/client-messages', Icons.chat_outlined, Icons.chat_rounded, 'Messages'),
    _NavItem('/client-invoices', Icons.receipt_long_outlined, Icons.receipt_long, 'Invoices'),
    _NavItem('/client-activity', Icons.notifications_outlined, Icons.notifications_rounded, 'Updates', badgeTab: true),
    _NavItem('/client-account', Icons.person_outline, Icons.person, 'Account'),
  ];

  /// Client Pro Plus: same Connect logo as freelancer (travel_explore ≈ web Compass).
  static const _clientPlusTabs = [
    _NavItem('/client-portal', Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem('/client-messages', Icons.chat_outlined, Icons.chat_rounded, 'Messages'),
    _NavItem('/connect', Icons.travel_explore_outlined, Icons.travel_explore, 'Connect', connectBadge: true),
    _NavItem('/client-invoices', Icons.receipt_long_outlined, Icons.receipt_long, 'Invoices'),
    _NavItem('/client-account', Icons.person_outline, Icons.person, 'Account'),
  ];

  int _indexFromLocation(String location, List<_NavItem> tabs) {
    // Prefer longest path match so /connect/listing highlights Connect.
    var best = 0;
    var bestLen = -1;
    for (var i = 0; i < tabs.length; i++) {
      final p = tabs[i].path;
      if (location == p || location.startsWith('$p/')) {
        if (p.length > bestLen) {
          best = i;
          bestLen = p.length;
        }
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isClient = isClientUser(user);
    final isPlus = ref.watch(isProPlusProvider);
    final tabs = isClient
        ? (isPlus ? _clientPlusTabs : _clientBaseTabs)
        : (isPlus ? _freelancerPlusTabs : _freelancerBaseTabs);
    final semantic = context.clivoraColors;
    final accent = semantic.brand;
    final navBackground = semantic.navBar;
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location, tabs);
    final badgeCount = ref.watch(unreadBadgeCountProvider);
    final connectBadge = ref.watch(connectPendingBadgeProvider).valueOrNull ?? 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await showExitDialog(context);
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OfflineStatusBar(),
            const SyncFailureBanner(),
            Container(
              margin: const EdgeInsets.fromLTRB(
                ClivoraSpacing.lg,
                0,
                ClivoraSpacing.lg,
                ClivoraSpacing.md,
              ),
              decoration: BoxDecoration(
                color: navBackground,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: navBackground.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: ClivoraSpacing.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (var i = 0; i < tabs.length; i++)
                        _BottomNavItem(
                          item: tabs[i],
                          selected: currentIndex == i,
                          accent: accent,
                          selectedLabelColor: semantic.navBarSelected,
                          errorColor: semantic.error,
                          badgeCount: tabs[i].badgeTab
                              ? badgeCount
                              : (tabs[i].connectBadge ? connectBadge : 0),
                          onTap: () => context.go(tabs[i].path),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(
    this.path,
    this.icon,
    this.activeIcon,
    this.label, {
    this.badgeTab = false,
    this.connectBadge = false,
  });

  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool badgeTab;
  final bool connectBadge;
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.item,
    required this.selected,
    required this.accent,
    required this.selectedLabelColor,
    required this.errorColor,
    required this.badgeCount,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final Color accent;
  final Color selectedLabelColor;
  final Color errorColor;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedLabelColor : Colors.white54;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 8, vertical: 6),
        decoration: selected
            ? BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? item.activeIcon : item.icon, color: color, size: 22),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: errorColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            if (selected) ...[
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
