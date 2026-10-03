import 'package:flutter/material.dart';

import '../../shared/widgets/clivora_scaffold.dart';

/// Shown wherever CLIVORA Enterprise has a feature this Community build does
/// not include, so an old link or deep link lands somewhere sensible instead
/// of a missing route.
class EditionScreen extends StatelessWidget {
  const EditionScreen({super.key, this.feature});

  /// Name of the Enterprise feature that was requested, if any.
  final String? feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requested = feature;
    return ClivoraScaffold(
      title: requested ?? 'CLIVORA Community',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.lock_open_rounded, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'You are using CLIVORA Community',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            requested == null
                ? 'Every feature in this build is unlocked. The Community edition has no paid tiers, usage limits or upgrades.'
                : '$requested is part of CLIVORA Enterprise and is not included in this open-source build. Everything else in the app is unlocked, with no paid tiers or limits.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Enterprise adds the admin console, billing and subscriptions, ERP and campaign integrations, and AI features for teams that run CLIVORA as a hosted service.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
