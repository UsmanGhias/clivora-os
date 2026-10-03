import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/user_roles.dart';
import '../../core/services/marketplace/connect_marketplace_service.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';

class ConnectListingScreen extends ConsumerStatefulWidget {
  const ConnectListingScreen({super.key});

  @override
  ConsumerState<ConnectListingScreen> createState() => _ConnectListingScreenState();
}

class _ConnectListingScreenState extends ConsumerState<ConnectListingScreen> {
  final _title = TextEditingController();
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _skills = TextEditingController();
  final _location = TextEditingController();
  String _rate = '\$200-500 / project';
  String _availability = 'available';
  bool _listed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final row = await ref.read(connectMarketplaceServiceProvider).myListing();
    if (row == null || !mounted) return;
    _title.text = row['display_title'] as String? ?? '';
    _headline.text = row['headline'] as String? ?? '';
    _bio.text = row['bio'] as String? ?? '';
    final skills = (row['skills'] as List?)?.map((e) => e.toString()).join(', ') ?? '';
    _skills.text = skills;
    _location.text = row['location_label'] as String? ?? '';
    _rate = row['rate_band'] as String? ?? _rate;
    _availability = row['availability'] as String? ?? _availability;
    _listed = row['is_listed'] as bool? ?? false;
    setState(() {});
  }

  @override
  void dispose() {
    _title.dispose();
    _headline.dispose();
    _bio.dispose();
    _skills.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isClient = isClientUser(user);
    final hasAccess = ref.watch(isProPlusProvider);

    return ClivoraScaffold(
      title: isClient ? 'My about listing' : 'My Connect listing',
      showBackButton: true,
      body: !hasAccess
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connect requires Pro Plus',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push('/upgrade'),
                    child: const Text('Upgrade to Pro Plus'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  isClient
                      ? 'Publish your company about so freelancers can discover you. Email stays hidden until you accept a Connect request. You can also post jobs from Connect.'
                      : 'Show skills and rate band only. Your email stays hidden until someone accepts your Connect request.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: isClient
                        ? 'Public company / project title'
                        : 'Public title (not your real name)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: _headline, decoration: const InputDecoration(labelText: 'Headline')),
                const SizedBox(height: 12),
                TextField(
                  controller: _bio,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: isClient ? 'About' : 'Bio'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _skills,
                  decoration: InputDecoration(
                    labelText: isClient
                        ? 'Looking for (skills, comma separated)'
                        : 'Skills (comma separated)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location label (optional)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_rate),
                  initialValue: _rate,
                  decoration: InputDecoration(
                    labelText: isClient ? 'Typical budget band' : 'Rate band',
                  ),
                  items: const [
                    DropdownMenuItem(value: '\$100-200 / project', child: Text('\$100-200 / project')),
                    DropdownMenuItem(value: '\$200-500 / project', child: Text('\$200-500 / project')),
                    DropdownMenuItem(value: '\$500-1,500 / project', child: Text('\$500-1,500 / project')),
                    DropdownMenuItem(value: '\$1,500+ / project', child: Text('\$1,500+ / project')),
                    DropdownMenuItem(value: 'negotiable', child: Text('Negotiable')),
                  ],
                  onChanged: (v) => setState(() => _rate = v ?? _rate),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_availability),
                  initialValue: _availability,
                  decoration: InputDecoration(
                    labelText: isClient ? 'Hiring status' : 'Availability',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'available',
                      child: Text(isClient ? 'Open to hire' : 'Available'),
                    ),
                    DropdownMenuItem(
                      value: 'limited',
                      child: Text(isClient ? 'Selective' : 'Limited'),
                    ),
                    DropdownMenuItem(
                      value: 'booked',
                      child: Text(isClient ? 'Not hiring now' : 'Booked'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _availability = v ?? _availability),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isClient ? 'List my about on Connect' : 'List me on Connect'),
                  value: _listed,
                  onChanged: (v) => setState(() => _listed = v),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Saving…' : 'Save listing'),
                ),
              ],
            ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final skills = _skills.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await ref.read(connectMarketplaceServiceProvider).upsertListing(
            displayTitle: _title.text,
            headline: _headline.text,
            bio: _bio.text,
            skills: skills,
            rateBand: _rate,
            availability: _availability,
            locationLabel: _location.text,
            isListed: _listed,
          );
      await ref.read(connectMarketplaceServiceProvider).logConnectEvent('connect_listing_saved');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing saved.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
