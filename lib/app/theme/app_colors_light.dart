import 'package:flutter/material.dart';

/// Light-mode counterpart to [AppColors], mirroring its roles field-for-field
/// so [AppTheme] can build either brightness from the same shape.
abstract final class AppColorsLight {
  static const background = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFEDF1F5);
  static const border = Color(0xFFD8DEE6);
  // Deepened from AppColors.accent (0xFF4DE3C1): that mint is legible as a
  // dark-surface highlight but fails text/icon contrast on a light surface.
  static const accent = Color(0xFF12876B);
  static const accentMuted = Color(0xFFDFF3EC);
  static const relay = Color(0xFF2F5FD9);
  static const textPrimary = Color(0xFF12181F);
  static const textSecondary = Color(0xFF57626D);
  static const success = Color(0xFF1E8E5A);
  static const warning = Color(0xFFAD6F06);
  static const danger = Color(0xFFD1354B);
  // Text/icon color for content placed on top of an `accent`-colored surface
  // (e.g. a filled button label) — white reads on this deeper accent, unlike
  // the near-black used for the same role in the dark theme.
  static const onAccent = Color(0xFFFFFFFF);
}
