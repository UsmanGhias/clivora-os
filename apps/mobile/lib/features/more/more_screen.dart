import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_service.dart';
import '../../core/constants/admin_config.dart';
import '../../core/services/app_engagement_service.dart';
import '../../core/auth/user_roles.dart';
import '../../core/utils/admin_helper.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/constants/plan_features.dart';
import '../../core/utils/navigation_helper.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_bottom_sheet.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/clivora_logo.dart';
import '../../shared/widgets/form_dialog_fields.dart';
import '../../shared/widgets/step_progress_card.dart';
import '../../shared/widgets/tool_grid_tile.dart';
import '../../core/services/analytics_export_service.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/billable_to_invoice_service.dart';
import '../../core/services/cloud_crm_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  Future<void> _billProjectToInvoice(BuildContext context, WidgetRef ref) async {
    final projects = await ref.read(projectsProvider(const ProjectFilter()).future);
    final active = projects.where((p) => p.status == 'in_progress' || p.status == 'completed').toList();
    if (active.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No projects available to bill')),
        );
      }
      return;
    }
    var projectId = active.first.id;
    final rateCtrl = TextEditingController(text: '0');
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Bill project to invoice'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: spacedDialogFields([
                DropdownButtonFormField<int>(
                  initialValue: projectId,
                  decoration: clivoraDialogFieldDecoration(ctx, 'Project'),
                  items: active.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) => setLocal(() => projectId = v ?? projectId),
                ),
                TextField(
                  controller: rateCtrl,
                  decoration: clivoraDialogFieldDecoration(ctx, 'Hourly rate (optional)'),
                  keyboardType: TextInputType.number,
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create draft')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final project = active.firstWhere((p) => p.id == projectId);
    try {
      final id = await ref.read(billableToInvoiceServiceProvider).createFromProject(
            projectId: project.id,
            customerId: project.customerId,
            hourlyRate: double.tryParse(rateCtrl.text.trim()) ?? 0,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Draft invoice #$id created')),
        );
        context.push('/invoices/$id/edit');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(businessProfileProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;

    final planAsync = ref.watch(subscriptionPlanProvider);
    final isPro = ref.watch(isProProvider);
    final isPlus = ref.watch(isProPlusProvider);
    final plan = planAsync.valueOrNull;
    final backupRemindAsync = ref.watch(cloudBackupReminderProvider);

    return ClivoraScaffold(
      title: 'Command Center',
      subtitle: 'All tools and resources in one place',
      showMessagesButton: true,
      // Narrower than default so Hub tiles use more of the screen width.
      padding: const EdgeInsets.symmetric(horizontal: 12),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
        children: [
          // Profile card kept compact - full settings live under Menu tab
          profileAsync.when(
            loading: () => const SizedBox(height: 8),
            error: (_, _) => const SizedBox.shrink(),
            data: (profile) => _ProfileCard(
              profile: profile,
              photoPath: authUser?.profilePhotoPath ?? profile.ownerPhotoPath,
              planLabel: isPlus
                  ? 'Pro Plus'
                  : isPro
                      ? 'Pro'
                      : 'Free',
              onEdit: () => openFormRoute(context, '/profile'),
            ),
          ),
          const SizedBox(height: 12),
          statsAsync.when(
            loading: () => const SizedBox(height: 8),
            error: (_, _) => const SizedBox.shrink(),
            data: (stats) => _StatsBar(stats: stats),
          ),
          if (backupRemindAsync.valueOrNull == true) ...[
            const SizedBox(height: 16),
            Material(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/backup'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: ClivoraColors.iconGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cloud_upload_outlined, color: ClivoraColors.successGreen),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cloud backup recommended', style: TextStyle(fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text(
                              'Protect clients & invoices before reinstall or device change.',
                              style: TextStyle(fontSize: 12, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (!isPlus) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'CLIVORA Connect'),
            Material(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  if (context.mounted) context.push('/connect');
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: ClivoraColors.navyDark,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.hub_outlined, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'What is Connect?',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Match with clients and freelancers privately',
                              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const SectionHeader(title: 'Work & collaboration'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.35,
            children: [
              ToolGridTile(
                icon: Icons.task_alt_outlined,
                label: 'Tasks',
                description: 'Manage and organize your tasks',
                iconBackground: ClivoraColors.iconOrange,
                iconColor: ClivoraColors.warningOrange,
                onTap: () => context.push('/tasks'),
              ),
              ToolGridTile(
                icon: Icons.cloud_sync_outlined,
                label: 'Workspace tasks',
                description: 'Cloud tasks synced with web',
                iconBackground: ClivoraColors.iconBlue,
                iconColor: Colors.blue,
                onTap: () => context.push('/workspace-tasks'),
              ),
              ToolGridTile(
                icon: Icons.calendar_today_outlined,
                label: 'Calendar',
                description: 'Schedule and manage your events',
                iconBackground: ClivoraColors.iconGreen,
                iconColor: ClivoraColors.successGreen,
                onTap: () async {
                  if (!PlanFeatures.calendarView(plan) && !await requireProFeature(context, isPro: isPro, featureName: 'Calendar', isClient: false)) {
                    return;
                  }
                  if (context.mounted) context.push('/calendar');
                },
              ),
              ToolGridTile(
                icon: Icons.account_tree_outlined,
                label: 'Automation builder',
                description: 'Cloud rules + durable jobs',
                iconBackground: ClivoraColors.iconOrange,
                iconColor: ClivoraColors.warningOrange,
                onTap: () => context.push('/automation-builder'),
              ),
              ToolGridTile(
                icon: Icons.merge_type_outlined,
                label: 'CRM conflicts',
                description: 'Keep local / Take cloud',
                iconBackground: ClivoraColors.iconRed,
                iconColor: Colors.redAccent,
                onTap: () => context.push('/crm-conflicts'),
              ),
              ToolGridTile(
                icon: Icons.sync_outlined,
                label: 'Sync Center',
                description: 'Outbox queue and retries',
                iconBackground: ClivoraColors.iconGreen,
                iconColor: ClivoraColors.successGreen,
                onTap: () => context.push('/sync-center'),
              ),
              ToolGridTile(
                icon: Icons.people_outline,
                label: 'Team',
                description: 'Manage your team and members',
                iconBackground: ClivoraColors.iconBlue,
                iconColor: Colors.blue,
                onTap: () async {
                  if (!PlanFeatures.teamCollaboration(plan) && !await requireProFeature(context, isPro: isPro, featureName: 'Team')) {
                    return;
                  }
                  if (context.mounted) context.push('/team');
                },
              ),
              ToolGridTile(
                icon: Icons.forum_outlined,
                label: 'Messages',
                description: 'Communicate with your team',
                iconBackground: ClivoraColors.iconTeal,
                iconColor: ClivoraColors.primary,
                onTap: () => context.go('/freelancer-messages'),
              ),
              ToolGridTile(
                icon: Icons.payment_outlined,
                label: 'Payments',
                description: 'Track payments and transactions',
                iconBackground: ClivoraColors.iconBlue,
                iconColor: Colors.blue,
                onTap: () => context.push('/payments'),
              ),
              ToolGridTile(
                icon: Icons.notifications_outlined,
                label: 'Follow-ups',
                description: 'Stay on top of important follow-ups',
                iconBackground: ClivoraColors.iconRed,
                iconColor: ClivoraColors.errorRed,
                onTap: () => context.push('/notifications'),
              ),
              ToolGridTile(
                icon: Icons.flag_outlined,
                label: 'Milestones',
                description: 'Track and manage project milestones',
                iconBackground: ClivoraColors.iconIndigo,
                iconColor: Colors.indigo,
                onTap: () => context.push('/projects'),
              ),
              ToolGridTile(
                icon: Icons.star_outline,
                label: 'Reviews',
                description: 'See feedback and client reviews',
                iconBackground: ClivoraColors.iconYellow,
                iconColor: ClivoraColors.accent,
                onTap: () => context.push('/reviews'),
              ),
              ToolGridTile(
                icon: Icons.cloud_outlined,
                label: 'File Vault',
                description: 'Securely store and access your files',
                iconBackground: ClivoraColors.iconBlue,
                iconColor: Colors.blue,
                onTap: () async {
                  if (!PlanFeatures.fileVault(plan) && !await requireProFeature(context, isPro: isPro, featureName: 'File Vault')) {
                    return;
                  }
                  if (context.mounted) context.push('/storage');
                },
              ),
              ToolGridTile(
                icon: Icons.note_outlined,
                label: 'Notes',
                description: 'Keep all your notes organized',
                iconBackground: ClivoraColors.iconOrange,
                iconColor: ClivoraColors.warningOrange,
                onTap: () => context.push('/notes'),
              ),
              ToolGridTile(
                icon: Icons.view_kanban_outlined,
                label: 'Projects',
                description: 'Kanban board and active work',
                iconBackground: ClivoraColors.iconIndigo,
                iconColor: Colors.indigo,
                onTap: () => context.go('/projects'),
              ),
              ToolGridTile(
                icon: Icons.receipt_long_outlined,
                label: 'Invoices',
                description: 'Create and track invoices',
                iconBackground: ClivoraColors.iconTeal,
                iconColor: ClivoraColors.primary,
                onTap: () => context.go('/invoices'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.35,
            children: [
              ToolGridTile(
                icon: Icons.inventory_2_outlined,
                label: 'Catalog',
                description: 'Products and services',
                iconBackground: ClivoraColors.iconTeal,
                iconColor: ClivoraColors.primary,
                onTap: () => context.push('/products'),
              ),
              ToolGridTile(
                icon: Icons.autorenew,
                label: 'Recurring',
                description: 'Recurring invoices',
                iconBackground: ClivoraColors.iconGreen,
                iconColor: ClivoraColors.successGreen,
                onTap: () => context.push('/recurring-invoices'),
              ),
              ToolGridTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Credits',
                description: 'Credit notes and adjustments',
                iconBackground: ClivoraColors.iconYellow,
                iconColor: ClivoraColors.accent,
                onTap: () => context.push('/credits'),
              ),
              ToolGridTile(
                icon: Icons.playlist_add_check_outlined,
                label: 'Bill work',
                description: 'Turn project time into invoices',
                iconBackground: ClivoraColors.iconGreen,
                iconColor: ClivoraColors.successGreen,
                onTap: () => _billProjectToInvoice(context, ref),
              ),
              ToolGridTile(
                icon: Icons.payments_outlined,
                label: 'Payment queue',
                description: 'Confirm client payments',
                iconBackground: ClivoraColors.iconTeal,
                iconColor: Colors.teal,
                onTap: () => context.push('/payment-confirmations'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
            ),
            child: const SectionHeader(title: 'Insights & ops'),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.35,
            children: [
              ToolGridTile(
                icon: Icons.bar_chart_outlined,
                label: 'Reports',
                description: 'View detailed reports and insights',
                iconBackground: ClivoraColors.iconBlue,
                iconColor: Colors.blue,
                onTap: () => context.push('/reports'),
              ),
              ToolGridTile(
                icon: Icons.insights_outlined,
                label: 'Analytics',
                description: 'Track performance and trends',
                iconBackground: ClivoraColors.iconTeal,
                iconColor: ClivoraColors.primary,
                onTap: () => context.push('/analytics'),
              ),
              ToolGridTile(
                icon: Icons.cloud_upload_outlined,
                label: 'Backup',
                description: 'Secure your data and restore anytime',
                iconBackground: ClivoraColors.iconGreen,
                iconColor: ClivoraColors.successGreen,
                onTap: () => context.push('/backup'),
              ),
              ToolGridTile(
                icon: Icons.ios_share_outlined,
                label: 'Export',
                description: 'Export your data in multiple formats',
                iconBackground: ClivoraColors.iconGreen,
                iconColor: ClivoraColors.successGreen,
                onTap: () async {
                  if (!PlanFeatures.dataExport(plan) && !await requireProFeature(context, isPro: isPro, featureName: 'Data export')) {
                    return;
                  }
                  try {
                    await ref.read(analyticsExportServiceProvider).exportAndShare();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                    }
                  }
                },
              ),
              ToolGridTile(
                icon: Icons.receipt_outlined,
                label: 'Expenses',
                description: 'Manage and track your expenses',
                iconBackground: ClivoraColors.iconRed,
                iconColor: ClivoraColors.errorRed,
                onTap: () => context.push('/expenses'),
              ),
              ToolGridTile(
                icon: Icons.forum_outlined,
                label: 'Templates',
                description: 'Use templates to save time and effort',
                iconBackground: ClivoraColors.iconTeal,
                iconColor: Colors.teal,
                onTap: () => context.push('/templates'),
              ),
              ToolGridTile(
                icon: Icons.description_outlined,
                label: 'Contracts',
                description: 'Create, manage and track contracts',
                iconBackground: ClivoraColors.iconTeal,
                iconColor: ClivoraColors.primary,
                onTap: () => context.push('/contracts'),
              ),
              ToolGridTile(
                icon: Icons.bolt_outlined,
                label: 'Workflows',
                description: 'Automate tasks and streamline work',
                iconBackground: ClivoraColors.iconYellow,
                iconColor: Colors.amber,
                onTap: () async {
                  if (!PlanFeatures.automations(plan) && !await requireProFeature(context, isPro: isPro, featureName: 'Workflows')) {
                    return;
                  }
                  if (context.mounted) context.push('/automations');
                },
              ),
              ToolGridTile(
                icon: Icons.request_quote_outlined,
                label: 'Quotes',
                description: 'Send quotes and convert to invoices',
                iconBackground: ClivoraColors.iconTeal,
                iconColor: ClivoraColors.primary,
                onTap: () => context.push('/quotes'),
              ),
              ToolGridTile(
                icon: Icons.forum_outlined,
                label: 'Community',
                description: 'Questions, ideas and help on GitHub',
                iconBackground: ClivoraColors.iconTeal,
                iconColor: ClivoraColors.primary,
                onTap: () => launchUrl(
                  Uri.parse('$kProjectUrl/discussions'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Workspace settings'),
          _SettingsTile(
            icon: Icons.person_outline,
            label: 'My Profile',
            subtitle: 'Photo, name, email, address',
            onTap: () => context.push('/profile'),
          ),
          if (isAdminUser(authUser))
            _SettingsTile(
              icon: Icons.admin_panel_settings_outlined,
              label: isSuperAdmin(authUser) ? 'Command Center' : 'Admin',
              onTap: () => context.push(isSuperAdmin(authUser) ? '/admin-console' : '/admin'),
            ),
          _SettingsTile(
            icon: Icons.business_outlined,
            label: 'Business Settings',
            onTap: () => _showBusinessSettings(context, ref),
          ),
          _SettingsTile(
            icon: Icons.shield_outlined,
            label: 'Security & Privacy',
            subtitle: 'Biometric lock, delete account, licenses',
            onTap: () => context.push('/security'),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            subtitle: 'Messages, billing, contracts, team',
            onTap: () => context.push('/notification-settings'),
          ),
          _SettingsTile(
            icon: Icons.palette_outlined,
            label: 'Invoice Branding',
            onTap: () => _showInvoiceBranding(context, ref),
          ),
          _SettingsTile(
            icon: Icons.verified_user_outlined,
            label: 'Founder Access',
            subtitle: 'All features unlocked · \$0 platform fees',
            onTap: () => context.push('/profile'),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Share & Grow'),
          _SettingsTile(
            icon: Icons.share_outlined,
            label: 'Share CLIVORA',
            subtitle: 'Tell friends about the app',
            onTap: () => ref.read(appEngagementServiceProvider).shareApp(),
          ),
          _SettingsTile(
            icon: Icons.star_outline,
            label: 'Rate on Google Play',
            onTap: () => ref.read(appEngagementServiceProvider).showRateDialog(context),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Appearance'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ClivoraColors.iconPurple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.wb_sunny_outlined, color: ClivoraColors.primaryPurple, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500))),
                Switch(
                  value: themeMode == ThemeMode.dark,
                  onChanged: (v) {
                    ref.read(themeModeProvider.notifier).setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
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
        ],
      ),
    );
  }

  void _showBusinessSettings(BuildContext context, WidgetRef ref) {
    final profile = ref.read(businessProfileProvider).valueOrNull;
    final nameController = TextEditingController(text: profile?.businessName ?? '');
    final emailController = TextEditingController(text: profile?.businessEmail ?? '');
    final phoneController = TextEditingController(text: profile?.businessPhone ?? '');
    final ownerController = TextEditingController(text: profile?.ownerName ?? '');
    var logoPath = profile?.logoPath;

    showClivoraBottomSheet(
      context: context,
      title: 'Business Settings',
      onSave: () async {
        final userId = ref.read(authStateProvider).valueOrNull?.id;
        if (userId == null) return;
        await ref.read(databaseProvider).saveBusinessProfileForUser(
              userId,
              BusinessProfilesCompanion(
                businessName: Value(nameController.text.trim()),
                businessEmail: Value(emailController.text.trim()),
                businessPhone: Value(phoneController.text.trim()),
                ownerName: Value(ownerController.text.trim()),
                logoPath: Value(logoPath),
              ),
            );
        ref.invalidate(businessProfileProvider);
      },
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ClivoraFieldLabel(label: 'Business Logo'),
              GestureDetector(
                onTap: () async {
                  final path = await pickAndSaveImage(ImageSource.gallery);
                  if (path != null) setModalState(() => logoPath = path);
                },
                child: Container(
                  width: double.infinity,
                  height: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ClivoraColors.chipBackground,
                    borderRadius: BorderRadius.circular(14),
                    image: logoPath != null && File(logoPath!).existsSync()
                        ? DecorationImage(image: FileImage(File(logoPath!)), fit: BoxFit.contain)
                        : null,
                  ),
                  child: logoPath == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_outlined, color: ClivoraColors.primaryPurple),
                            SizedBox(height: 4),
                            Text('Upload logo', style: TextStyle(color: ClivoraColors.primaryPurple)),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text('Logo appears on invoice PDFs when branding is enabled.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 20),
              ClivoraTextField(controller: ownerController, label: 'Owner Name', hint: 'Your name'),
              const SizedBox(height: 16),
              ClivoraTextField(controller: nameController, label: 'Business Name', hint: 'Business name'),
              const SizedBox(height: 16),
              ClivoraTextField(controller: emailController, label: 'Business Email', hint: 'email@business.com', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              ClivoraTextField(controller: phoneController, label: 'Business Phone', hint: '+1 (555) 123-4567', keyboardType: TextInputType.phone),
            ],
          );
        },
      ),
    );
  }

  void _showInvoiceBranding(BuildContext context, WidgetRef ref) async {
    final branding = ref.read(invoiceBrandingProvider).valueOrNull;
    var accentColor = branding?.accentColor ?? '#6C63FF';
    var templateStyle = branding?.templateStyle ?? 'classic';
    var showLogo = branding?.showLogo ?? true;
    final prefs = await SharedPreferences.getInstance();
    final ntnCtrl = TextEditingController(text: prefs.getString('branding_ntn') ?? '');
    final paymentCtrl = TextEditingController(text: prefs.getString('branding_payment_instructions') ?? '');
    if (!context.mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return ClivoraBottomSheet(
            title: 'Invoice Branding',
            onSave: () async {
              final userId = ref.read(authStateProvider).valueOrNull?.id;
              if (userId == null) return;
              await ref.read(databaseProvider).saveInvoiceBrandingForUser(
                    userId,
                    InvoiceBrandingsCompanion(
                      accentColor: Value(accentColor),
                      templateStyle: Value(templateStyle),
                      showLogo: Value(showLogo),
                    ),
                  );
              final p = await SharedPreferences.getInstance();
              await p.setString('branding_ntn', ntnCtrl.text.trim());
              await p.setString('branding_payment_instructions', paymentCtrl.text.trim());
              ref.invalidate(invoiceBrandingProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invoice branding saved')),
                );
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ClivoraFieldLabel(label: 'Accent Color'),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final color in _accentColors)
                      GestureDetector(
                        onTap: () => setModalState(() => accentColor = color),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _hexColor(color),
                            shape: BoxShape.circle,
                            border: accentColor == color ? Border.all(color: Colors.white, width: 2) : null,
                          ),
                          child: accentColor == color ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const ClivoraFieldLabel(label: 'Template Style'),
                _TemplateOption(
                  title: 'Classic',
                  description: 'Clean gray backgrounds, timeless layout.',
                  selected: templateStyle == 'classic',
                  onTap: () => setModalState(() => templateStyle = 'classic'),
                ),
                const SizedBox(height: 8),
                _TemplateOption(
                  title: 'Modern',
                  description: 'Soft blue-tinted backgrounds, contemporary.',
                  selected: templateStyle == 'modern',
                  onTap: () => setModalState(() => templateStyle = 'modern'),
                ),
                const SizedBox(height: 8),
                _TemplateOption(
                  title: 'Minimal',
                  description: 'White surfaces with subtle borders.',
                  selected: templateStyle == 'minimal',
                  onTap: () => setModalState(() => templateStyle = 'minimal'),
                ),
                const SizedBox(height: 8),
                _TemplateOption(
                  title: 'Bold',
                  description: 'Strong accent bar and large title.',
                  selected: templateStyle == 'bold',
                  onTap: () => setModalState(() => templateStyle = 'bold'),
                ),
                const SizedBox(height: 16),
                ClivoraTextField(controller: ntnCtrl, label: 'NTN', hint: 'Tax / NTN number'),
                const SizedBox(height: 12),
                ClivoraTextField(
                  controller: paymentCtrl,
                  label: 'Payment instructions',
                  hint: 'Bank details, JazzCash, EasyPaisa…',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Text('Show Business Logo', style: TextStyle(fontWeight: FontWeight.w500))),
                    Switch(
                      value: showLogo,
                      onChanged: (v) => setModalState(() => showLogo = v),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

const _accentColors = [
  '#6C63FF',
  '#3B82F6',
  '#14B8A6',
  '#22C55E',
  '#F97316',
  '#EF4444',
  '#A855F7',
  '#1A1C2E',
];

Color _hexColor(String hex) {
  final value = hex.replaceAll('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onEdit, this.photoPath, required this.planLabel});

  final BusinessProfile profile;
  final VoidCallback onEdit;
  final String? photoPath;
  final String planLabel;

  @override
  Widget build(BuildContext context) {
    final since = DateFormat('yyyy').format(profile.memberSince);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClivoraColors.navyDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                photoPath: photoPath,
                name: profile.ownerName,
                radius: 28,
                onTap: onEdit,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.ownerName.isNotEmpty ? profile.ownerName : 'CLIVORA User',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      profile.businessName.isNotEmpty ? profile.businessName : 'Not set',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Since $since', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond_outlined, color: Colors.white70, size: 12),
                    const SizedBox(width: 4),
                    Text(planLabel, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          if (profile.businessEmail.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [Icon(Icons.email_outlined, color: Colors.white.withValues(alpha: 0.5), size: 16), const SizedBox(width: 8), Expanded(child: Text(profile.businessEmail, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)))]),
          ],
          const SizedBox(height: 8),
          Row(children: [Icon(Icons.phone_outlined, color: Colors.white.withValues(alpha: 0.5), size: 16), const SizedBox(width: 8), Text(profile.businessPhone.isNotEmpty ? profile.businessPhone : 'Not set', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13))]),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? ClivoraColors.darkBorder : Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        children: [
          _StatCol('${stats.customers}', 'Customers'),
          _StatDivider(),
          _StatCol('${stats.activeProjects}', 'Active'),
          _StatDivider(),
          _StatCol(formatCurrency(stats.outstanding > 0 ? stats.outstanding : stats.revenue), stats.outstanding > 0 ? 'Due' : 'Earned'),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
    );
  }
}

class _StatCol extends StatelessWidget {
  const _StatCol(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.label, required this.onTap, this.subtitle});

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: ClivoraColors.primaryPurple),
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _TemplateOption extends StatelessWidget {
  const _TemplateOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? ClivoraColors.primaryPurple.withValues(alpha: 0.08) : ClivoraColors.chipBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? ClivoraColors.primaryPurple : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? ClivoraColors.primaryPurple : ClivoraColors.labelGray, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? ClivoraColors.primaryPurple : null)),
                  Text(description, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
