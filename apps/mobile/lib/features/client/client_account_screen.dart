import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/form_validators.dart';
import '../../data/database/database.dart';
import '../../core/services/app_engagement_service.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_logo.dart';

/// Client account, profile, quick links, sign out.
class ClientAccountScreen extends ConsumerStatefulWidget {
  const ClientAccountScreen({super.key});

  @override
  ConsumerState<ClientAccountScreen> createState() =>
      _ClientAccountScreenState();
}

class _ClientAccountScreenState extends ConsumerState<ClientAccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _populate(User? user) {
    if (user == null) return;
    _nameController.text = user.name;
    _emailController.text = user.email;
    _initialized = true;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (!mounted || file == null) return;
    final error = await ref
        .read(authStateProvider.notifier)
        .updateProfilePhoto(file.path);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Profile photo updated')));
  }

  Future<void> _save() async {
    final nameErr = FormValidators.requiredField(
      _nameController.text,
      field: 'Name',
    );
    if (nameErr != null) {
      showFormError(context, nameErr);
      return;
    }
    final emailErr = FormValidators.email(
      _emailController.text,
      required: true,
    );
    if (emailErr != null) {
      showFormError(context, emailErr);
      return;
    }
    setState(() => _saving = true);
    final error = await ref
        .read(authStateProvider.notifier)
        .updateProfile(
          name: _nameController.text,
          email: _emailController.text,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      showFormError(context, error);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account updated')));
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You can sign back in anytime with the same email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await ref.read(authStateProvider.notifier).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final projectCount =
        ref.watch(clientSharedProjectsProvider).valueOrNull?.length ?? 0;
    final isPro = ref.watch(isProProvider);
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (!_initialized && user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _populate(user));
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'My Account',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: ClivoraColors.clientGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: ClivoraColors.clientAccent.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _pickPhoto(ImageSource.gallery),
                    child: Stack(
                      children: [
                        ProfileAvatar(
                          photoPath: user?.profilePhotoPath,
                          name: user?.name ?? 'C',
                          radius: 36,
                          showVerified: isPro,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 14,
                              color: ClivoraColors.clientAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'CLIENT ACCOUNT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.name ?? 'Client',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$projectCount shared project${projectCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Share & rewards'),
            const SizedBox(height: 10),
            _QuickLinkTile(
              icon: Icons.share_outlined,
              label: 'Share CLIVORA',
              onTap: () => ref.read(appEngagementServiceProvider).shareApp(),
            ),
            _QuickLinkTile(
              icon: Icons.star_outline,
              label: 'Rate on Google Play',
              onTap: () => ref
                  .read(appEngagementServiceProvider)
                  .showRateDialog(context),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Quick links'),
            const SizedBox(height: 10),
            _QuickLinkTile(
              icon: Icons.person_outline,
              label: 'Edit full profile',
              onTap: () => context.push('/profile'),
            ),
            _QuickLinkTile(
              icon: Icons.apps_outlined,
              label: 'Client Hub',
              onTap: () => context.push('/client-hub'),
            ),
            _QuickLinkTile(
              icon: Icons.request_quote_outlined,
              label: 'Quotes',
              onTap: () => context.push('/client-quotes'),
            ),
            _QuickLinkTile(
              icon: Icons.timeline_outlined,
              label: 'Updates',
              onTap: () => context.push('/client-activity'),
            ),
            _QuickLinkTile(
              icon: Icons.folder_shared_outlined,
              label: 'Shared projects',
              onTap: () => context.go('/client-portal'),
            ),
            _QuickLinkTile(
              icon: Icons.mail_outline_rounded,
              label: 'Messages',
              onTap: () => context.go('/client-messages'),
            ),
            _QuickLinkTile(
              icon: Icons.notifications_outlined,
              label: 'Updates & notifications',
              onTap: () => context.go('/client-activity'),
            ),
            _QuickLinkTile(
              icon: Icons.person_add_alt_1_outlined,
              label: 'Link a freelancer',
              onTap: () => context.push('/client-link-freelancer'),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Appearance'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ClivoraColors.clientSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.wb_sunny_outlined,
                      color: ClivoraColors.clientAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Switch(
                    value: themeMode == ThemeMode.dark,
                    onChanged: (v) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Profile details'),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'FULL NAME',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'EMAIL',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Freelancers share projects and invoices with this email.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: ClivoraColors.clientAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save changes'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: ClivoraColors.errorRed,
                side: const BorderSide(color: ClivoraColors.errorRed),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Sign out'),
            ),
            const SizedBox(height: 32),
            const Center(child: ClivoraLogo(size: 28, borderRadius: 8)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
        leading: Icon(icon),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 20,
          color: colorScheme.onSurface.withValues(alpha: 0.45),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
