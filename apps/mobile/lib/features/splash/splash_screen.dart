import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_route_helper.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/onboarding_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/exit_dialog.dart';
import '../../shared/widgets/clivora_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    await ref.read(authStateProvider.notifier).ensureLoaded();
    if (!mounted) return;

    final onboardingDone = await ref.read(onboardingServiceProvider).isComplete();
    if (!mounted) return;

    final guidelinesSeen = await ref.read(onboardingServiceProvider).guidelinesSeen();
    if (!mounted) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      final bio = ref.read(biometricServiceProvider);
      if (await bio.isEnabled && await bio.canUseBiometric() && await bio.shouldPromptUnlock()) {
        final ok = await bio.authenticate(reason: 'Unlock CLIVORA');
        if (!mounted) return;
        if (!ok) {
          await ref.read(authStateProvider.notifier).signOut();
          if (mounted) context.go('/login');
          return;
        }
      } else {
        bio.markSessionUnlocked();
      }
      if (!mounted) return;
      context.go(homeRouteForUser(user));
    } else if (!guidelinesSeen) {
      context.go('/value-guidelines');
    } else if (!onboardingDone) {
      context.go('/onboarding');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await showExitDialog(context);
      },
      child: Scaffold(
        backgroundColor: ClivoraColors.navyDark,
        body: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ClivoraLogo(size: 120, borderRadius: 28),
                  const SizedBox(height: 24),
                  const Text(
                    'CLIVORA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Business Operating System',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ClivoraColors.primaryPurple.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
