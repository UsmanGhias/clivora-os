import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/clivora_colors.dart';
import '../../core/utils/navigation_helper.dart';
import '../../data/providers/app_providers.dart';

/// Top-bar messages shortcut with optional unread badge.
class MessagesIconButton extends ConsumerWidget {
  const MessagesIconButton({
    super.key,
    required this.route,
    this.iconColor,
    this.useFilledStyle = false,
  });

  final String route;
  final Color? iconColor;
  final bool useFilledStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadMessagesProvider);
    final unread = unreadAsync.valueOrNull ?? 0;
    final color = iconColor ?? Theme.of(context).iconTheme.color;

    final icon = Icon(Icons.mail_outline_rounded, color: color, size: 22);

    final button = useFilledStyle
        ? Material(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => openFormRoute(context, route),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 40, height: 40, child: icon),
            ),
          )
        : IconButton(
            onPressed: () => openFormRoute(context, route),
            icon: icon,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? ClivoraColors.chipBackground
                  : ClivoraColors.darkBorder,
            ),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        if (unread > 0)
          Positioned(
            right: useFilledStyle ? 4 : 6,
            top: useFilledStyle ? 4 : 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                decoration: const BoxDecoration(color: ClivoraColors.errorRed, shape: BoxShape.circle),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
