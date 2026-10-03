import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/clivora_colors.dart';
import '../../shared/widgets/clivora_logo.dart';

/// One-time value proposition shown after splash for new installs.
class ValueGuidelinesScreen extends StatelessWidget {
  const ValueGuidelinesScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 720;
    final logoSize = compact ? 60.0 : 72.0;

    return Scaffold(
      backgroundColor: ClivoraColors.navyDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: ClivoraLogo(size: logoSize, borderRadius: 18)),
                    SizedBox(height: compact ? 14 : 20),
                    Text(
                      'Work with integrity',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 22 : null,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Most freelancing platforms charge high fees on every invoice, message, and milestone. '
                      'CLIVORA brings clients and freelancers together on one honest workspace.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.45,
                        fontSize: compact ? 14 : 15,
                      ),
                    ),
                    SizedBox(height: compact ? 16 : 20),
                    _GuidelineCard(
                      compact: compact,
                      icon: Icons.handshake_outlined,
                      title: 'Clients and freelancers together',
                      body: 'Share projects, tasks, invoices, and messages in real time with full transparency.',
                    ),
                    const SizedBox(height: 10),
                    _GuidelineCard(
                      compact: compact,
                      icon: Icons.timeline_outlined,
                      title: 'Tracking clients can trust',
                      body: 'Clients see progress, updates, and completed work without chasing screenshots.',
                    ),
                    const SizedBox(height: 10),
                    _ProPricingCard(compact: compact),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: onContinue,
                    style: FilledButton.styleFrom(
                      backgroundColor: ClivoraColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Continue to CLIVORA'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      'Already have an account?',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidelineCard extends StatelessWidget {
  const _GuidelineCard({
    required this.compact,
    required this.icon,
    required this.title,
    required this.body,
  });

  final bool compact;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ClivoraColors.primary, size: compact ? 24 : 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 14 : 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.4,
                    fontSize: compact ? 12 : 13,
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

class _ProPricingCard extends StatelessWidget {
  const _ProPricingCard({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ClivoraColors.primary.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClivoraColors.primary.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 38 : 44,
            height: compact ? 38 : 44,
            decoration: BoxDecoration(
              color: ClivoraColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.workspace_premium_outlined,
              color: ClivoraColors.primary,
              size: compact ? 22 : 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Free and open source',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 15 : 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ClivoraColors.accent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'AGPL-3.0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 10 : 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Community edition · runs on your own Supabase',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unlimited clients, team collaboration and every workspace tool, with no paid tiers.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.35,
                    fontSize: compact ? 12 : 13,
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
