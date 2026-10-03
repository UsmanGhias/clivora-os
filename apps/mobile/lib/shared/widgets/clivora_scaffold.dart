import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/clivora_colors.dart';
import '../../core/theme/clivora_tokens.dart';
import '../../core/theme/theme_context.dart';
import 'messages_icon_button.dart';

class ClivoraScaffold extends StatelessWidget {
  const ClivoraScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.action,
    this.showBackButton = false,
    this.showMessagesButton = false,
    this.messagesRoute = '/freelancer-messages',
    this.padding,
    this.floatingActionButton,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? action;
  final bool showBackButton;
  final bool showMessagesButton;
  final String messagesRoute;
  final EdgeInsets? padding;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final layout = context.clivoraLayout;
    final screenPadding = padding ??
        EdgeInsets.symmetric(horizontal: layout.screenPadding);

    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: screenPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showBackButton) ...[
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).brightness == Brightness.light
                            ? ClivoraColors.chipBackground
                            : ClivoraColors.darkBorder,
                      ),
                    ),
                    const SizedBox(width: ClivoraSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: ClivoraColors.textSecondary,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showMessagesButton) ...[
                    MessagesIconButton(route: messagesRoute),
                    if (action != null) const SizedBox(width: ClivoraSpacing.sm),
                  ],
                  ?action,
                ],
              ),
            ),
            const SizedBox(height: ClivoraSpacing.sm),
            Expanded(
              child: Padding(
                padding: screenPadding,
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClivoraIconButton extends StatelessWidget {
  const ClivoraIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? ClivoraColors.chipBackground
            : ClivoraColors.darkBorder,
      ),
    );
  }
}
