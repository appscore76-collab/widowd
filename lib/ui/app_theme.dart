import 'package:flutter/material.dart';

import '../landing/landing_style.dart';

/// Colors from the widowd app design (the iOS app canvas), shared by every
/// signed-in page and the sign-in screens.
abstract final class AppColors {
  static const ink = Color(0xFF1B2421);
  static const muted = Color(0xFF5B6763);
  static const mutedDark = Color(0xFF3F4A46);
  static const teal = LandingColors.teal;
  static const tealDark = Color(0xFF163F3D);
  static const tealTint = LandingColors.tealTint;
  static const mist = LandingColors.mist;
  static const border = Color(0xFFC9D3CF);
  static const line = Color(0xFFE3E8E6);
  static const radioOff = Color(0xFF8C9894);
  static const gold = LandingColors.gold;
  static const amber = LandingColors.amber;
  static const sand = LandingColors.sand;
  static const sandText = LandingColors.brown;
  static const sandTextDark = LandingColors.brownDark;
  static const onTeal = LandingColors.onTeal;
  static const verifiedBg = Color(0xFFE5EDFD);
  static const verifiedText = Color(0xFF1E40AF);
  static const verifiedTextDark = Color(0xFF1E3A8A);
  static const verifiedIcon = Color(0xFF2563EB);
  static const photoTint = Color(0xFFC8D9D3);
  static const photoIcon = Color(0xFF5E7D73);
  static const error = Color(0xFFB3261E);
}

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ).copyWith(
        primary: AppColors.teal,
        onPrimary: Colors.white,
        primaryContainer: AppColors.tealTint,
        onPrimaryContainer: AppColors.tealDark,
        secondaryContainer: AppColors.photoTint,
        onSecondaryContainer: AppColors.photoIcon,
        tertiaryContainer: AppColors.sand,
        onTertiaryContainer: AppColors.sandText,
        surface: Colors.white,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.muted,
        outline: AppColors.border,
        outlineVariant: AppColors.line,
        error: AppColors.error,
      );

  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: landingFont,
    scaffoldBackgroundColor: AppColors.mist,
  );
  final text = base.textTheme.apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  const pill = StadiumBorder();
  final buttonText = jakarta(17, weight: 700);

  OutlineInputBorder field(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: jakarta(
        28,
        weight: 800,
        color: AppColors.ink,
        height: 1.2,
        letterSpacingEm: -0.5 / 28,
      ),
      headlineSmall: jakarta(
        22,
        weight: 800,
        color: AppColors.ink,
        letterSpacingEm: -0.4 / 22,
      ),
      titleLarge: jakarta(20, weight: 800, color: AppColors.ink),
      titleMedium: jakarta(16, weight: 800, color: AppColors.ink),
      titleSmall: jakarta(15, weight: 700, color: AppColors.ink),
      bodyLarge: jakarta(16, color: AppColors.ink, height: 1.45),
      bodyMedium: jakarta(15, color: AppColors.ink, height: 1.5),
      bodySmall: jakarta(13, color: AppColors.muted, height: 1.4),
      labelLarge: jakarta(15, weight: 700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.mist,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: jakarta(18, weight: 800, color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.teal.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(64, 56),
        shape: pill,
        textStyle: buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 24),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.teal,
        minimumSize: const Size(64, 52),
        shape: pill,
        side: const BorderSide(color: AppColors.teal, width: 2),
        textStyle: jakarta(15, weight: 700),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.teal,
        minimumSize: const Size(44, 44),
        textStyle: jakarta(15, weight: 600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: jakarta(15, color: AppColors.muted),
      floatingLabelStyle: jakarta(15, weight: 600, color: AppColors.teal),
      helperStyle: jakarta(12, color: AppColors.muted),
      hintStyle: jakarta(15, color: AppColors.muted),
      border: field(AppColors.border),
      enabledBorder: field(AppColors.border),
      focusedBorder: field(AppColors.teal, 2),
      errorBorder: field(AppColors.error),
      focusedErrorBorder: field(AppColors.error, 2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.tealTint,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => jakarta(
          11,
          weight: states.contains(WidgetState.selected) ? 700 : 600,
          color: states.contains(WidgetState.selected)
              ? AppColors.teal
              : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.teal
              : AppColors.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: jakarta(14, weight: 600, color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.teal,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
  );
}
