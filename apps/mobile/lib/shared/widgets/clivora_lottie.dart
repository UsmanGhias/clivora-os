import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Lottie with icon fallback for offline / desktop testing.
class ClivoraLottie extends StatelessWidget {
  const ClivoraLottie({
    super.key,
    required this.asset,
    this.fallbackIcon = Icons.auto_awesome_outlined,
    this.size = 120,
    this.repeat = true,
  });

  final String asset;
  final IconData fallbackIcon;
  final double size;
  final bool repeat;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        asset,
        repeat: repeat,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(fallbackIcon, size: size * 0.5, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
