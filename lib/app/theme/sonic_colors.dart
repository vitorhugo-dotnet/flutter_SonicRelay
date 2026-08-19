import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_colors_light.dart';

/// Brand/semantic colors with no matching [ColorScheme] role (e.g.
/// `success`/`warning` have no Material equivalent). Roles that do map onto
/// `ColorScheme` — accent -> primary, danger -> error, secondary text ->
/// onSurfaceVariant, hairlines -> outline — are read straight off
/// [ColorScheme] instead of being duplicated here.
@immutable
class SonicColors extends ThemeExtension<SonicColors> {
  const SonicColors({
    required this.accentMuted,
    required this.relay,
    required this.success,
    required this.warning,
    required this.surfaceElevated,
  });

  final Color accentMuted;
  final Color relay;
  final Color success;
  final Color warning;
  final Color surfaceElevated;

  static const dark = SonicColors(
    accentMuted: AppColors.accentMuted,
    relay: AppColors.relay,
    success: AppColors.success,
    warning: AppColors.warning,
    surfaceElevated: AppColors.surfaceElevated,
  );

  static const light = SonicColors(
    accentMuted: AppColorsLight.accentMuted,
    relay: AppColorsLight.relay,
    success: AppColorsLight.success,
    warning: AppColorsLight.warning,
    surfaceElevated: AppColorsLight.surfaceElevated,
  );

  @override
  SonicColors copyWith({
    Color? accentMuted,
    Color? relay,
    Color? success,
    Color? warning,
    Color? surfaceElevated,
  }) => SonicColors(
    accentMuted: accentMuted ?? this.accentMuted,
    relay: relay ?? this.relay,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    surfaceElevated: surfaceElevated ?? this.surfaceElevated,
  );

  @override
  SonicColors lerp(ThemeExtension<SonicColors>? other, double t) {
    if (other is! SonicColors) return this;
    return SonicColors(
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      relay: Color.lerp(relay, other.relay, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
    );
  }
}

extension SonicColorsX on BuildContext {
  /// Falls back to [SonicColors.dark] outside of a themed [MaterialApp]
  /// (e.g. a widget test that pumps a bare [Directionality]); every real
  /// screen renders under [AppTheme], which always registers this extension.
  SonicColors get sonicColors =>
      Theme.of(this).extension<SonicColors>() ?? SonicColors.dark;
}
