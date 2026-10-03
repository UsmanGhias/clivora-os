import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/services/sync_outbox_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/crm_refresh.dart';

/// Shell banner for sync *problems only* (conflicts / permanent failures).
/// Plain pending work stays quiet - Sync Center shows the queue.
/// While offline, [OfflineStatusBar] owns the message (no double banner).
class SyncFailureBanner extends ConsumerWidget {
  const SyncFailureBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    if (!online) return const SizedBox.shrink();

    final message = ref.watch(syncFailureMessageProvider);
    if (message == null || message.isEmpty) return const SizedBox.shrink();

    return Material(
      color: ClivoraColors.warningOrange.withValues(alpha: 0.15),
      child: InkWell(
        onTap: () async {
          // Prefer Sync Center for conflicts; otherwise retry the queue.
          final msg = ref.read(syncFailureMessageProvider) ?? '';
          if (msg.toLowerCase().contains('conflict')) {
            if (context.mounted) context.push('/sync-center');
            return;
          }
          final outbox = ref.read(syncOutboxServiceProvider);
          await outbox.processQueue();
          invalidateOnReconnect(ref);
          await outbox.ensureMigrated();
          // Banner state is refreshed by _updateBanner inside processQueue.
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.sync_problem_outlined, size: 16, color: ClivoraColors.warningOrange),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
              const Icon(Icons.refresh, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
