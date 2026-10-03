import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../l10n/app_localizations.dart';

/// Thin offline indicator for the app shell.
class OfflineStatusBar extends ConsumerWidget {
  const OfflineStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineAsync = ref.watch(isOnlineProvider);

    return onlineAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (online) {
        if (online) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_outlined, size: 14, color: ClivoraColors.warningOrange),
              const SizedBox(width: 6),
              Text(
                l10n?.offlineBanner ?? 'Offline mode. Changes sync when you reconnect.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ClivoraColors.navyDark.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
