import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_colors_light.dart';
import 'app_typography.dart';
import 'sonic_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    background: AppColors.background,
    surface: AppColors.surface,
    border: AppColors.border,
    accent: AppColors.accent,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    danger: AppColors.danger,
    onAccent: AppColors.background,
    surfaceElevated: AppColors.surfaceElevated,
    extension: SonicColors.dark,
  );

  static ThemeData get light => _build(
    brightness: Brightness.light,
    background: AppColorsLight.background,
    surface: AppColorsLight.surface,
    border: AppColorsLight.border,
    accent: AppColorsLight.accent,
    textPrimary: AppColorsLight.textPrimary,
    textSecondary: AppColorsLight.textSecondary,
    danger: AppColorsLight.danger,
    onAccent: AppColorsLight.onAccent,
    surfaceElevated: AppColorsLight.surfaceElevated,
    extension: SonicColors.light,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color border,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required Color danger,
    required Color onAccent,
    required Color surfaceElevated,
    required SonicColors extension,
  }) {
    final scheme =
        (brightness == Brightness.dark
                ? const ColorScheme.dark()
                : const ColorScheme.light())
            .copyWith(
              primary: accent,
              onPrimary: onAccent,
              secondary: accent,
              onSecondary: onAccent,
              surface: surface,
              onSurface: textPrimary,
              onSurfaceVariant: textSecondary,
              error: danger,
              outline: border,
              surfaceContainerHighest: surfaceElevated,
            );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: AppTypography.textTheme(
        primary: textPrimary,
        secondary: textSecondary,
        onAccent: onAccent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      dividerColor: border,
      extensions: [extension],
    );
  }
}
