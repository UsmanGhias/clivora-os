import 'package:flutter/material.dart';

abstract final class ClivoraColors {
  // CLIVORA brand, teal + slate (distinct from purple CRM clones)
  static const primary = Color(0xFF0D9488);
  static const primaryDark = Color(0xFF0F766E);
  static const primaryLight = Color(0xFFCCFBF1);
  static const accent = Color(0xFFF59E0B);

  static const navyDark = Color(0xFF0F172A);
  static const background = Color(0xFFFAFAF9);
  static const surface = Color(0xFFFFFFFF);
  static const successGreen = Color(0xFF10B981);
  static const warningOrange = Color(0xFFF59E0B);
  static const errorRed = Color(0xFFDC2626);
  static const labelGray = Color(0xFF94A3B8);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const borderLight = Color(0xFFE2E8F0);
  static const chipBackground = Color(0xFFF1F5F9);
  static const outstandingPink = Color(0xFFFFF7ED);

  static const darkBackground = Color(0xFF0B1120);
  static const darkSurface = Color(0xFF1E293B);
  static const darkBorder = Color(0xFF334155);

  static const iconPurple = Color(0xFFCCFBF1);
  static const iconOrange = Color(0xFFFFEDD5);
  static const iconGreen = Color(0xFFD1FAE5);
  static const iconBlue = Color(0xFFDBEAFE);
  static const iconTeal = Color(0xFFCCFBF1);
  static const iconRed = Color(0xFFFEE2E2);
  static const iconIndigo = Color(0xFFE0E7FF);
  static const iconYellow = Color(0xFFFEF3C7);

  // Legacy alias for gradual migration
  static const primaryPurple = primary;

  /// Client portal, minimal slate palette (distinct from freelancer teal).
  static const clientAccent = Color(0xFF475569);
  static const clientAccentLight = Color(0xFFF8FAFC);
  static const clientSurface = Color(0xFFF1F5F9);
  static const clientMuted = Color(0xFF94A3B8);

  static LinearGradient get brandGradient => const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF0D9488)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get clientGradient => const LinearGradient(
        colors: [Color(0xFF1E293B), Color(0xFF64748B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
