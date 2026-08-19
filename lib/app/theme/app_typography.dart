import 'package:flutter/material.dart';

abstract final class AppTypography {
  /// [onAccent] is the label color for text placed on top of an
  /// accent-colored surface (e.g. a filled button) — it isn't simply the
  /// inverse of [primary]/[secondary] because the accent color's own
  /// lightness differs between the light and dark themes.
  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
    required Color onAccent,
  }) => TextTheme(
    displaySmall: TextStyle(
      color: primary,
      fontSize: 36,
      fontWeight: FontWeight.w700,
      height: 1.1,
      letterSpacing: -1,
    ),
    headlineMedium: TextStyle(
      color: primary,
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    titleLarge: TextStyle(color: primary, fontSize: 20, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: primary, fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(color: secondary, fontSize: 14, height: 1.5),
    labelLarge: TextStyle(color: onAccent, fontSize: 15, fontWeight: FontWeight.w700),
  );
}
