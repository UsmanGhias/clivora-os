import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/user_roles.dart';
import '../../core/constants/countries.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/email_verification_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/form_validators.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_logo.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/country_picker_field.dart';
import '../../shared/widgets/step_progress_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalController = TextEditingController();
  final _bioController = TextEditingController();
  final _clientCompanyController = TextEditingController();
  final _clientIndustryController = TextEditingController();
  final _clientWebsiteController = TextEditingController();
  final _skillInputController = TextEditingController();
  String? _country;
  List<String> _skills = [];
  bool _initialized = false;
  bool _saving = false;
  bool _verifyBusy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    _bioController.dispose();
    _clientCompanyController.dispose();
    _clientIndustryController.dispose();
    _clientWebsiteController.dispose();
    _skillInputController.dispose();
    super.dispose();
  }

  void _populateFields(User? user, BusinessProfile? profile) {
    if (user == null && profile == null) return;
    _nameController.text = user?.name ?? profile?.ownerName ?? '';
    _emailController.text = user?.email ?? profile?.businessEmail ?? '';
    _phoneController.text = profile?.businessPhone ?? '';
    _addressController.text = profile?.businessAddress ?? '';
    _cityController.text = profile?.businessCity ?? '';
    _postalController.text = profile?.businessPostalCode ?? '';
    _country = (profile?.businessCountry.isNotEmpty == true) ? profile!.businessCountry : kDefaultCountry;
    _bioController.text = profile?.bio ?? '';
    _clientCompanyController.text = profile?.clientCompany ?? '';
    _clientIndustryController.text = profile?.clientIndustry ?? '';
    _clientWebsiteController.text = profile?.clientWebsite ?? '';
    _skills = parseSkillsJson(profile?.skills ?? '[]');
    _initialized = true;
  }

  void _addSkill() {
    final s = _skillInputController.text.trim();
    if (s.isEmpty) return;
    if (!_skills.contains(s)) {
      setState(() {
        _skills = [..._skills, s];
        _skillInputController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() => _skills = _skills.where((x) => x != skill).toList());
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    if (!mounted || file == null) return;

    final error = await ref.read(authStateProvider.notifier).updateProfilePhoto(file.path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Profile photo updated')),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final emailErr = FormValidators.email(_emailController.text, required: true);
    if (emailErr != null) {
      showFormError(context, emailErr);
      return;
    }
    final nameErr = FormValidators.requiredField(_nameController.text, field: 'Name');
    if (nameErr != null) {
      showFormError(context, nameErr);
      return;
    }

    setState(() => _saving = true);
    try {
    final error = await ref.read(authStateProvider.notifier).updateProfile(
          name: _nameController.text,
          email: _emailController.text,
        );
    if (error != null) {
      if (mounted) showFormError(context, error);
      return;
    }

    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;

    await ref.read(databaseProvider).saveBusinessProfileForUser(
          userId,
          BusinessProfilesCompanion(
            ownerName: Value(_nameController.text.trim()),
            businessEmail: Value(_emailController.text.trim()),
            businessPhone: Value(_phoneController.text.trim()),
            businessAddress: Value(_addressController.text.trim()),
            businessCity: Value(_cityController.text.trim()),
            businessPostalCode: Value(_postalController.text.trim()),
            businessCountry: Value(_country ?? kDefaultCountry),
            bio: Value(_bioController.text.trim()),
            skills: Value(skillsToJson(_skills)),
            clientCompany: Value(_clientCompanyController.text.trim()),
            clientIndustry: Value(_clientIndustryController.text.trim()),
            clientWebsite: Value(_clientWebsiteController.text.trim()),
          ),
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resendVerification() async {
    if (_verifyBusy) return;
    setState(() => _verifyBusy = true);
    try {
      final err = await ref.read(emailVerificationServiceProvider).resendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err ?? 'Verification email sent. Check inbox and spam, then tap “I’ve verified”.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _verifyBusy = false);
    }
  }

  Future<void> _refreshVerification() async {
    if (_verifyBusy) return;
    setState(() => _verifyBusy = true);
    try {
      await ref.read(emailVerificationServiceProvider).syncFromSupabase();
      if (!mounted) return;
      final user = ref.read(authStateProvider).valueOrNull;
      final ok = ref.read(emailVerificationServiceProvider).isVerified(user);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Email verified, you can start creating clients, invoices, and projects.'
                : 'Still unverified. Open the link in your email, then try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _verifyBusy = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime with the same email.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
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
    final isClient = isClientUser(user);
    final isPro = ref.watch(isProProvider);
    final profileAsync = ref.watch(businessProfileProvider);
    final profile = profileAsync.valueOrNull;
    final photoPath = user?.profilePhotoPath ?? profile?.ownerPhotoPath;

    if (!_initialized && (user != null || profile != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _populateFields(user, profile));
      });
    }

    return ClivoraScaffold(
      title: isClient ? 'My Account' : 'Business Profile',
      showBackButton: true,
      body: profileAsync.isLoading && !_initialized
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Stack(
                    children: [
                      ProfileAvatar(
                        photoPath: photoPath,
                        name: _nameController.text,
                        radius: 48,
                        showVerified: isPro,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Material(
                          color: ClivoraColors.primaryPurple,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _showPhotoOptions,
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.camera_alt, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text('Tap camera to update photo', style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(height: 16),
                _EmailVerificationCard(
                  user: user,
                  busy: _verifyBusy,
                  onResend: _resendVerification,
                  onRefresh: _refreshVerification,
                ),
                const SizedBox(height: 24),
                ClivoraTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                ClivoraTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 16),
                ClivoraTextField(
                  controller: _phoneController,
                  label: 'Phone',
                  hint: 'Add your phone number',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                ),
                const SizedBox(height: 16),
                ClivoraTextField(
                  controller: _bioController,
                  label: isClient ? 'About You' : 'Bio / Tagline',
                  hint: isClient ? 'Tell freelancers about yourself…' : 'Tell us about your business...',
                  maxLines: 4,
                  prefixIcon: Icons.info_outline,
                ),
                if (!isClient) ...[
                  const SizedBox(height: 20),
                  Text('Skills', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final skill in _skills)
                        Chip(
                          label: Text(skill),
                          onDeleted: () => _removeSkill(skill),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClivoraTextField(
                          controller: _skillInputController,
                          hint: 'Add skill (e.g. Flutter, Dart, UI/UX)',
                          prefixIcon: Icons.auto_awesome_outlined,
                          onSubmitted: (_) => _addSkill(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: ClivoraColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _addSkill,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: ClivoraColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (isClient) ...[
                  const SizedBox(height: 16),
                  ClivoraTextField(
                    controller: _clientCompanyController,
                    label: 'Company / Organization',
                    prefixIcon: Icons.business_outlined,
                  ),
                  const SizedBox(height: 16),
                  ClivoraTextField(
                    controller: _clientIndustryController,
                    label: 'Industry',
                    hint: 'e.g. Retail, Tech, Healthcare',
                    prefixIcon: Icons.category_outlined,
                  ),
                  const SizedBox(height: 16),
                  ClivoraTextField(
                    controller: _clientWebsiteController,
                    label: 'Website (optional)',
                    keyboardType: TextInputType.url,
                    prefixIcon: Icons.language_outlined,
                  ),
                ],
                const SizedBox(height: 16),
                ClivoraTextField(
                  controller: _addressController,
                  label: isClient ? 'Address' : 'Business Address',
                  hint: isClient ? null : 'Add your business address',
                  prefixIcon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ClivoraTextField(
                        controller: _cityController,
                        label: 'City',
                        hint: 'Enter city',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClivoraTextField(
                        controller: _postalController,
                        label: 'Postal',
                        hint: 'Enter postal code',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CountryPickerField(value: _country, onChanged: (v) => setState(() => _country = v)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isClient ? 'Save Profile' : 'Save Changes'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _signOut,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClivoraColors.errorRed,
                      side: BorderSide(color: ClivoraColors.primary.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Sign Out', style: TextStyle(color: ClivoraColors.errorRed, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmailVerificationCard extends ConsumerWidget {
  const _EmailVerificationCard({
    required this.user,
    required this.busy,
    required this.onResend,
    required this.onRefresh,
  });

  final User? user;
  final bool busy;
  final VoidCallback onResend;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user == null || isGuestUser(user) || isAdminUser(user)) {
      return const SizedBox.shrink();
    }
    final verified = ref.watch(emailVerificationServiceProvider).isVerified(user);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: verified
          ? ClivoraColors.successGreen.withValues(alpha: 0.08)
          : scheme.errorContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  verified ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
                  color: verified ? ClivoraColors.successGreen : scheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    verified ? 'Email verified' : 'Verify your email to start work',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              verified
                  ? 'You’re all set to create clients, invoices, projects, and more.'
                  : 'You can browse your account, but creating clients, invoices, projects, tasks, or expenses requires a verified email. We sent a link to ${user!.email}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!verified) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onResend,
                      child: Text(busy ? 'Please wait…' : 'Resend email'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : onRefresh,
                      child: const Text('I’ve verified'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
