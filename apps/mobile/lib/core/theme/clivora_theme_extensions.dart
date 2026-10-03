import 'package:flutter/material.dart';

import 'clivora_colors.dart';
import 'clivora_tokens.dart';

/// Semantic theme tokens exposed via [ThemeExtension] for consistent UI polish.
@immutable
class ClivoraSemanticColors extends ThemeExtension<ClivoraSemanticColors> {
  const ClivoraSemanticColors({
    required this.brand,
    required this.brandMuted,
    required this.navBar,
    required this.navBarSelected,
    required this.chipBg,
    required this.chipSelectedBg,
    required this.chipSelectedBorder,
    required this.success,
    required this.warning,
    required this.error,
    required this.gradientStart,
    required this.gradientEnd,
    required this.isClientPortal,
  });

  final Color brand;
  final Color brandMuted;
  final Color navBar;
  final Color navBarSelected;
  final Color chipBg;
  final Color chipSelectedBg;
  final Color chipSelectedBorder;
  final Color success;
  final Color warning;
  final Color error;
  final Color gradientStart;
  final Color gradientEnd;
  final bool isClientPortal;

  static ClivoraSemanticColors freelancerLight() => const ClivoraSemanticColors(
        brand: ClivoraColors.primary,
        brandMuted: ClivoraColors.primaryLight,
        navBar: ClivoraColors.navyDark,
        navBarSelected: ClivoraColors.primary,
        chipBg: ClivoraColors.chipBackground,
        chipSelectedBg: Color(0x140D9488),
        chipSelectedBorder: ClivoraColors.primary,
        success: ClivoraColors.successGreen,
        warning: ClivoraColors.warningOrange,
        error: ClivoraColors.errorRed,
        gradientStart: Color(0xFF0F172A),
        gradientEnd: Color(0xFF0D9488),
        isClientPortal: false,
      );

  static ClivoraSemanticColors freelancerDark() => const ClivoraSemanticColors(
        brand: ClivoraColors.primary,
        brandMuted: Color(0xFF134E4A),
        navBar: Color(0xFF0F172A),
        navBarSelected: ClivoraColors.primary,
        chipBg: ClivoraColors.darkBorder,
        chipSelectedBg: Color(0x330D9488),
        chipSelectedBorder: ClivoraColors.primary,
        success: ClivoraColors.successGreen,
        warning: ClivoraColors.warningOrange,
        error: ClivoraColors.errorRed,
        gradientStart: Color(0xFF0B1120),
        gradientEnd: Color(0xFF0F766E),
        isClientPortal: false,
      );

  static ClivoraSemanticColors clientLight() => const ClivoraSemanticColors(
        brand: ClivoraColors.clientAccent,
        brandMuted: ClivoraColors.clientSurface,
        navBar: Color(0xFF334155),
        navBarSelected: Color(0xFF94A3B8),
        chipBg: ClivoraColors.clientSurface,
        chipSelectedBg: Color(0x1A475569),
        chipSelectedBorder: ClivoraColors.clientAccent,
        success: ClivoraColors.successGreen,
        warning: ClivoraColors.warningOrange,
        error: ClivoraColors.errorRed,
        gradientStart: Color(0xFF1E293B),
        gradientEnd: Color(0xFF64748B),
        isClientPortal: true,
      );

  static ClivoraSemanticColors clientDark() => freelancerDark().copyWith(
        brand: ClivoraColors.clientAccent,
        brandMuted: Color(0xFF334155),
        navBar: Color(0xFF1E293B),
        navBarSelected: Color(0xFFCBD5E1),
        isClientPortal: true,
      );

  LinearGradient get brandGradient => LinearGradient(
        colors: [gradientStart, gradientEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  @override
  ClivoraSemanticColors copyWith({
    Color? brand,
    Color? brandMuted,
    Color? navBar,
    Color? navBarSelected,
    Color? chipBg,
    Color? chipSelectedBg,
    Color? chipSelectedBorder,
    Color? success,
    Color? warning,
    Color? error,
    Color? gradientStart,
    Color? gradientEnd,
    bool? isClientPortal,
  }) {
    return ClivoraSemanticColors(
      brand: brand ?? this.brand,
      brandMuted: brandMuted ?? this.brandMuted,
      navBar: navBar ?? this.navBar,
      navBarSelected: navBarSelected ?? this.navBarSelected,
      chipBg: chipBg ?? this.chipBg,
      chipSelectedBg: chipSelectedBg ?? this.chipSelectedBg,
      chipSelectedBorder: chipSelectedBorder ?? this.chipSelectedBorder,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      isClientPortal: isClientPortal ?? this.isClientPortal,
    );
  }

  @override
  ClivoraSemanticColors lerp(ThemeExtension<ClivoraSemanticColors>? other, double t) {
    if (other is! ClivoraSemanticColors) return this;
    return ClivoraSemanticColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandMuted: Color.lerp(brandMuted, other.brandMuted, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      navBarSelected: Color.lerp(navBarSelected, other.navBarSelected, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      chipSelectedBg: Color.lerp(chipSelectedBg, other.chipSelectedBg, t)!,
      chipSelectedBorder: Color.lerp(chipSelectedBorder, other.chipSelectedBorder, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      isClientPortal: t < 0.5 ? isClientPortal : other.isClientPortal,
    );
  }
}

@immutable
class ClivoraLayoutTokens extends ThemeExtension<ClivoraLayoutTokens> {
  const ClivoraLayoutTokens({
    required this.screenPadding,
    required this.cardRadius,
    required this.buttonRadius,
    required this.chipRadius,
    required this.minTouchTarget,
  });

  final double screenPadding;
  final double cardRadius;
  final double buttonRadius;
  final double chipRadius;
  final double minTouchTarget;

  static const standard = ClivoraLayoutTokens(
    screenPadding: ClivoraSpacing.screenH,
    cardRadius: ClivoraRadii.lg,
    buttonRadius: ClivoraRadii.md,
    chipRadius: ClivoraRadii.pill,
    minTouchTarget: ClivoraSpacing.minTouch,
  );

  @override
  ClivoraLayoutTokens copyWith({
    double? screenPadding,
    double? cardRadius,
    double? buttonRadius,
    double? chipRadius,
    double? minTouchTarget,
  }) {
    return ClivoraLayoutTokens(
      screenPadding: screenPadding ?? this.screenPadding,
      cardRadius: cardRadius ?? this.cardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      chipRadius: chipRadius ?? this.chipRadius,
      minTouchTarget: minTouchTarget ?? this.minTouchTarget,
    );
  }

  @override
  ClivoraLayoutTokens lerp(ThemeExtension<ClivoraLayoutTokens>? other, double t) => this;
}
