import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/user_roles.dart';
import '../../core/services/app_engagement_service.dart';
import '../../core/services/app_update_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/admin_helper.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_logo.dart';
import '../../shared/widgets/clivora_scaffold.dart';

/// Freelancer Menu tab - workspace settings & account (Command Center mockup).
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(businessProfileProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final isPro = ref.watch(isProProvider);
    final isPlus = ref.watch(isProPlusProvider);
    final themeMode = ref.watch(themeModeProvider);

    return ClivoraScaffold(
      title: 'Command Center',
      subtitle: 'Manage your workspace and preferences',
      showMessagesButton: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        children: [
          profileAsync.when(
            loading: () => const SizedBox(height: 72),
            error: (_, _) => const SizedBox.shrink(),
            data: (profile) {
              final name = authUser?.name.isNotEmpty == true
                  ? authUser!.name
                  : (profile.ownerName.isNotEmpty ? profile.ownerName : 'Freelancer');
              final photo = authUser?.profilePhotoPath ?? profile.ownerPhotoPath;
              return Material(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.push('/profile'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? ClivoraColors.darkBorder
                            : ClivoraColors.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        ProfileAvatar(
                          photoPath: photo,
                          name: name,
                          radius: 26,
                          showVerified: isPro,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(
                                isPlus
                                    ? 'Pro Plus member'
                                    : isPro
                                        ? 'Pro member'
                                        : 'Free plan',
                                style: const TextStyle(fontSize: 12, color: ClivoraColors.textSecondary),
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
            },
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Workspace settings'),
          _MenuTile(
            icon: Icons.person_outline,
            label: 'My Profile',
            subtitle: 'Photo, name, email, address',
            onTap: () => context.push('/profile'),
          ),
          if (isAdminUser(authUser))
            _MenuTile(
              icon: Icons.admin_panel_settings_outlined,
              label: isSuperAdmin(authUser) ? 'Command Center' : 'Admin',
              subtitle: 'Workspace settings',
              onTap: () => context.push(isSuperAdmin(authUser) ? '/admin-console' : '/admin'),
            ),
          _MenuTile(
            icon: Icons.business_outlined,
            label: 'Business Settings',
            subtitle: 'Company, billing, currency',
            onTap: () => context.push('/more'),
          ),
          _MenuTile(
            icon: Icons.shield_outlined,
            label: 'Security & Privacy',
            subtitle: 'Biometric lock, delete account, licenses',
            onTap: () => context.push('/security'),
          ),
          _MenuTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            subtitle: 'Messages, billing, contracts, team',
            onTap: () => context.push('/notification-settings'),
          ),
          _MenuTile(
            icon: Icons.palette_outlined,
            label: 'Invoice Branding',
            subtitle: 'Customize invoice templates',
            onTap: () => context.push('/more'),
          ),
          _MenuTile(
            icon: Icons.verified_user_outlined,
            label: 'Founder Access',
            subtitle: 'All features unlocked · \$0 platform fees',
            onTap: () => context.push('/profile'),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Share & Grow'),
          _MenuTile(
            icon: Icons.share_outlined,
            label: 'Share CLIVORA',
            subtitle: 'Tell friends about the app',
            onTap: () => ref.read(appEngagementServiceProvider).shareApp(),
          ),
          _MenuTile(
            icon: Icons.star_outline,
            label: 'Rate on Google Play',
            subtitle: 'Rate us and support',
            onTap: () => ref.read(appEngagementServiceProvider).showRateDialog(context),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Appearance'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? ClivoraColors.darkBorder
                    : ClivoraColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ClivoraColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.wb_sunny_outlined, color: ClivoraColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600))),
                Switch(
                  value: themeMode == ThemeMode.dark,
                  activeThumbColor: Colors.white,
                  activeTrackColor: ClivoraColors.primary,
                  onChanged: (v) {
                    ref.read(themeModeProvider.notifier).setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _SectionLabel('Data & Updates'),
          _MenuTile(
            icon: Icons.system_update_outlined,
            label: 'Check for app update',
            subtitle: 'Install from Play without losing data',
            onTap: () async {
              try {
                await ref.read(appUpdateServiceProvider).checkForUpdate(forceStoreFallback: true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
          ),
          _MenuTile(
            icon: Icons.apps_outlined,
            label: 'All tools',
            subtitle: 'Open full Command Center Hub',
            onTap: () => context.go('/more'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ClivoraColors.labelGray,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? ClivoraColors.darkBorder : ClivoraColors.borderLight),
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
                  child: Icon(icon, color: ClivoraColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(fontSize: 12, color: ClivoraColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: ClivoraColors.labelGray),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
