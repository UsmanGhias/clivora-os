import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/clivora_colors.dart';
import '../../data/providers/app_providers.dart';
import '../../core/utils/navigation_helper.dart';

/// Top-bar notifications shortcut with unread badge.
class NotificationIconButton extends ConsumerWidget {
  const NotificationIconButton({
    super.key,
    this.isClient = false,
    this.iconColor,
    this.useFilledStyle = false,
  });

  final bool isClient;
  final Color? iconColor;
  final bool useFilledStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeCount = ref.watch(unreadBadgeCountProvider);
    final color = iconColor ?? Theme.of(context).iconTheme.color;

    void onTap() => openNotifications(context, isClient: isClient);

    final icon = Icon(Icons.notifications_none_rounded, color: color, size: 22);

    final button = useFilledStyle
        ? Material(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 44, height: 44, child: Center(child: icon)),
            ),
          )
        : IconButton(
            onPressed: onTap,
            icon: icon,
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? ClivoraColors.chipBackground
                  : ClivoraColors.darkBorder,
            ),
          );

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          if (badgeCount > 0)
            Positioned(
              right: useFilledStyle ? 2 : 4,
              top: useFilledStyle ? 2 : 4,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: const BoxDecoration(
                    color: ClivoraColors.errorRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
