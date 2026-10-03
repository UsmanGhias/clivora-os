import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'clivora_colors.dart';
import 'clivora_theme_extensions.dart';
import 'clivora_tokens.dart';

enum ClivoraPortal { freelancer, client }

abstract final class ClivoraTheme {
  static ThemeData light({ClivoraPortal portal = ClivoraPortal.freelancer}) {
    final isClient = portal == ClivoraPortal.client;
    final semantic = isClient
        ? ClivoraSemanticColors.clientLight()
        : ClivoraSemanticColors.freelancerLight();
    final primary = isClient ? ClivoraColors.clientAccent : ClivoraColors.primary;
    final onPrimary = Colors.white;
    final secondary = isClient ? ClivoraColors.clientMuted : ClivoraColors.navyDark;

    final colorScheme = ColorScheme.light(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: semantic.brandMuted,
      onPrimaryContainer: ClivoraColors.textPrimary,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: ClivoraColors.surface,
      onSurface: ClivoraColors.textPrimary,
      onSurfaceVariant: ClivoraColors.textSecondary,
      outline: ClivoraColors.borderLight,
      outlineVariant: ClivoraColors.chipBackground,
      error: ClivoraColors.errorRed,
      onError: Colors.white,
      tertiary: ClivoraColors.accent,
    );

    return _baseTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackground: ClivoraColors.background,
      semantic: semantic,
      cardBorder: ClivoraColors.borderLight,
      inputFill: const Color(0xFFF3F4F6),
      inputHint: ClivoraColors.textSecondary,
      elevatedButtonBg: isClient ? ClivoraColors.clientAccent : ClivoraColors.navyDark,
      iconButtonBg: ClivoraColors.chipBackground,
      snackBarBg: ClivoraColors.navyDark,
      bottomSheetBg: ClivoraColors.surface,
    );
  }

  static ThemeData dark({ClivoraPortal portal = ClivoraPortal.freelancer}) {
    final isClient = portal == ClivoraPortal.client;
    final semantic = isClient
        ? ClivoraSemanticColors.clientDark()
        : ClivoraSemanticColors.freelancerDark();
    final primary = isClient ? ClivoraColors.clientAccent : ClivoraColors.primary;

    final colorScheme = ColorScheme.dark(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: semantic.brandMuted,
      onPrimaryContainer: Colors.white,
      secondary: ClivoraColors.darkSurface,
      onSecondary: Colors.white,
      surface: ClivoraColors.darkSurface,
      onSurface: Colors.white,
      onSurfaceVariant: ClivoraColors.labelGray,
      outline: ClivoraColors.darkBorder,
      outlineVariant: ClivoraColors.darkBorder,
      error: ClivoraColors.errorRed,
      onError: Colors.white,
      tertiary: ClivoraColors.accent,
    );

    return _baseTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackground: ClivoraColors.darkBackground,
      semantic: semantic,
      cardBorder: ClivoraColors.darkBorder,
      inputFill: ClivoraColors.darkBorder,
      inputHint: ClivoraColors.labelGray,
      elevatedButtonBg: primary,
      iconButtonBg: ClivoraColors.darkBorder,
      snackBarBg: ClivoraColors.darkSurface,
      bottomSheetBg: ClivoraColors.darkSurface,
    );
  }

  static ThemeData _baseTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required ClivoraSemanticColors semantic,
    required Color cardBorder,
    required Color inputFill,
    required Color inputHint,
    required Color elevatedButtonBg,
    required Color iconButtonBg,
    required Color snackBarBg,
    required Color bottomSheetBg,
  }) {
    final layout = ClivoraLayoutTokens.standard;
    final textTheme = _textTheme(brightness);
    final inter = GoogleFonts.interTextTheme(textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBackground,
      colorScheme: colorScheme,
      textTheme: inter,
      extensions: [semantic, layout],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: inter.headlineLarge,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 22),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(layout.cardRadius),
          side: BorderSide(color: cardBorder, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClivoraRadii.sm + 2),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClivoraRadii.sm + 2),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClivoraRadii.sm + 2),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClivoraRadii.sm + 2),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ClivoraSpacing.lg,
          vertical: 14,
        ),
        hintStyle: GoogleFonts.inter(color: inputHint),
        labelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: ClivoraColors.labelGray,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: elevatedButtonBg,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: Size(0, layout.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: ClivoraSpacing.xl,
            vertical: ClivoraSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(layout.buttonRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: Size(0, layout.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: ClivoraSpacing.xl,
            vertical: ClivoraSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(layout.buttonRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: Size(0, layout.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: ClivoraSpacing.xl,
            vertical: ClivoraSpacing.lg,
          ),
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(layout.buttonRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: Size(0, layout.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: ClivoraSpacing.lg,
            vertical: ClivoraSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClivoraRadii.sm + 2),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(layout.buttonRadius),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: semantic.chipBg,
        selectedColor: semantic.chipSelectedBg,
        disabledColor: semantic.chipBg.withValues(alpha: 0.5),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(layout.chipRadius),
          side: BorderSide(color: Colors.transparent),
        ),
        side: BorderSide(color: Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBarBg,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(layout.buttonRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bottomSheetBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(layout.cardRadius),
          ),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(layout.cardRadius),
        ),
        titleTextStyle: inter.titleLarge,
        contentTextStyle: inter.bodyMedium,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ClivoraSpacing.lg,
          vertical: ClivoraSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClivoraRadii.sm),
        ),
        iconColor: colorScheme.onSurfaceVariant,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: iconButtonBg,
          foregroundColor: colorScheme.onSurface,
          minimumSize: Size(layout.minTouchTarget, layout.minTouchTarget),
          // Keep soft chrome, but leave breathing room so adjacent icons don't merge.
          padding: const EdgeInsets.all(10),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClivoraRadii.sm + 2),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.4);
          }
          return cardBorder;
        }),
      ),
      dividerTheme: DividerThemeData(
        color: cardBorder,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final color = brightness == Brightness.light
        ? ClivoraColors.textPrimary
        : Colors.white;
    final secondary = brightness == Brightness.light
        ? ClivoraColors.textSecondary
        : const Color(0xFFCBD5E1);

    return TextTheme(
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: color),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: color),
      bodySmall: GoogleFonts.inter(fontSize: 12, color: secondary),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: brightness == Brightness.light ? ClivoraColors.labelGray : const Color(0xFF94A3B8),
      ),
    );
  }
}
