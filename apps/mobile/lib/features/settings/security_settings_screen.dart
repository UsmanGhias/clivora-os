import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/constants/legal_documents.dart';
import '../../core/constants/plan_features.dart';
import '../../core/services/account_deletion_service.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/coach_marks_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import 'legal_document_screen.dart';

/// Security, privacy, and accessibility preferences.
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool? _biometricSupported;
  bool _biometricEnabled = false;
  bool _coachMarksEnabled = true;
  int _timeoutMinutes = 30;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bio = ref.read(biometricServiceProvider);
    final supported = await bio.isSupported;
    final enabled = await bio.isEnabled;
    final timeout = await bio.timeoutMinutes();
    final coachEnabled = await ref.read(coachMarksServiceProvider).isEnabled();
    if (mounted) {
      setState(() {
        _biometricSupported = supported;
        _biometricEnabled = enabled;
        _timeoutMinutes = timeout;
        _coachMarksEnabled = coachEnabled;
        _loading = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value && !PlanFeatures.biometricLock(ref.read(subscriptionPlanProvider).valueOrNull)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric lock is a Pro feature. Upgrade to enable.')),
        );
        context.push('/upgrade');
      }
      return;
    }
    if (value) {
      if (_biometricSupported != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometrics not available on this device')),
          );
        }
        return;
      }
      final ok = await ref.read(biometricServiceProvider).authenticate(
            reason: 'Confirm to enable biometric lock',
            force: true,
          );
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric verification failed')),
          );
        }
        return;
      }
    }
    await ref.read(biometricServiceProvider).setEnabled(value);
    if (value) {
      ref.read(biometricServiceProvider).markSessionUnlocked();
    }
    setState(() => _biometricEnabled = value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'Biometric lock enabled' : 'Biometric lock disabled')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final emailCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This removes local data on this device and signs you out. Type your email to confirm.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: user.email,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ClivoraColors.errorRed),
            onPressed: () => Navigator.pop(ctx, emailCtrl.text.trim().isNotEmpty),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref.read(accountDeletionServiceProvider).deleteAccount(
            confirmEmail: emailCtrl.text.trim(),
          );
      if (mounted) {
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account deletion requested. Local data cleared and you have been signed out.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete account: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(isProProvider);
    return ClivoraScaffold(
      title: 'Security & Privacy',
      showBackButton: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Security', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.phonelink_lock_outlined),
                    title: const Text('Two-factor authentication (MFA)'),
                    subtitle: const Text(
                      'Add TOTP authenticator protection to your CLIVORA account via Supabase Auth. Biometric lock below secures this device.',
                    ),
                    isThreeLine: true,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Biometric lock'),
                  subtitle: Text(
                    !isPro
                        ? 'Pro feature, save your account with fingerprint or face'
                        : _biometricSupported == true
                            ? 'Require fingerprint or face when opening the app'
                            : 'Not available on this device',
                  ),
                  value: _biometricEnabled && (_biometricSupported ?? false) && isPro,
                  onChanged: isPro && (_biometricSupported ?? false) ? _toggleBiometric : null,
                ),
                if (_biometricEnabled && (_biometricSupported ?? false) && isPro)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonFormField<int>(
                      initialValue: _timeoutMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Lock after idle',
                        border: OutlineInputBorder(),
                      ),
                      items: BiometricService.timeoutOptions
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text('$m minutes'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        await ref.read(biometricServiceProvider).setTimeoutMinutes(v);
                        setState(() => _timeoutMinutes = v);
                      },
                    ),
                  ),
                SwitchListTile(
                  title: const Text('Dashboard tips'),
                  subtitle: const Text('Show one-time guide highlights on Home'),
                  value: _coachMarksEnabled,
                  onChanged: (v) async {
                    await ref.read(coachMarksServiceProvider).setEnabled(v);
                    setState(() => _coachMarksEnabled = v);
                  },
                ),
                const Divider(height: 32),
                Text('Legal', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Privacy policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LegalDocumentScreen(
                        title: LegalDocuments.privacyTitle,
                        updated: LegalDocuments.privacyUpdated,
                        body: LegalDocuments.privacyBody,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: const Text('Terms of service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LegalDocumentScreen(
                        title: LegalDocuments.termsTitle,
                        updated: LegalDocuments.termsUpdated,
                        body: LegalDocuments.termsBody,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _deleteAccount,
                  icon: const Icon(Icons.delete_forever_outlined, color: ClivoraColors.errorRed),
                  label: const Text('Delete my account', style: TextStyle(color: ClivoraColors.errorRed)),
                ),
              ],
            ),
    );
  }
}
