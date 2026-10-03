import 'package:flutter/material.dart';

import '../../core/theme/clivora_colors.dart';
import '../../shared/widgets/clivora_logo.dart';
import '../../shared/widgets/clivora_lottie.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.groups_outlined,
      title: 'Manage clients and projects',
      body: 'Keep customers, work, invoices, and tasks in one workspace built for freelancers.',
      color: ClivoraColors.primary,
    ),
    _OnboardingPage(
      icon: Icons.receipt_long_outlined,
      title: 'Send branded invoices',
      body: 'Create PDF invoices, track payments, and share them with clients through the portal.',
      color: ClivoraColors.primaryPurple,
    ),
    _OnboardingPage(
      icon: Icons.cloud_sync_outlined,
      title: 'Works offline, syncs online',
      body: 'Your data stays on your device. Cloud sync keeps clients and notifications connected.',
      color: ClivoraColors.successGreen,
    ),
    _OnboardingPage(
      icon: Icons.lock_outline,
      title: 'Private and secure',
      body: 'Optional biometric lock, encrypted session storage, and full data export when you need it.',
      color: ClivoraColors.navyDark,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  const ClivoraLogo(size: 36, borderRadius: 10),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onComplete,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: p.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: i == 2
                              ? const Center(child: ClivoraLottie(asset: 'assets/lottie/pulse.json', size: 72))
                              : Icon(p.icon, size: 44, color: p.color),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          p.body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: ClivoraColors.textSecondary,
                                height: 1.5,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? page.color : ClivoraColors.labelGray.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_index == _pages.length - 1 ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
