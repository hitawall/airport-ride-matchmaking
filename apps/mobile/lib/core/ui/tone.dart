import "package:material_ui/material_ui.dart";
import "../app_theme.dart";

/// Semantic colour roles used by banners, pills and tiles so screens never
/// pick container colours ad hoc.
enum AppTone { info, safety, success, warning, error, brand, neutral }

class ToneColors {
  const ToneColors({required this.background, required this.foreground, required this.icon});

  final Color background;
  final Color foreground;
  final IconData icon;
}

extension AppToneResolve on AppTone {
  ToneColors resolve(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    switch (this) {
      case AppTone.info:
        return ToneColors(
          background: colors.skyContainer,
          foreground: colors.onSkyContainer,
          icon: Icons.info_outline,
        );
      case AppTone.safety:
        return ToneColors(
          background: colors.mossContainer,
          foreground: colors.onMossContainer,
          icon: Icons.shield_outlined,
        );
      case AppTone.success:
        return ToneColors(
          background: colors.mossContainer,
          foreground: colors.onMossContainer,
          icon: Icons.check_circle_outline,
        );
      case AppTone.warning:
        return ToneColors(
          background: colors.amberContainer,
          foreground: colors.onAmberContainer,
          icon: Icons.warning_amber_rounded,
        );
      case AppTone.error:
        return ToneColors(
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
          icon: Icons.error_outline,
        );
      case AppTone.brand:
        return ToneColors(
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
          icon: Icons.flight_takeoff,
        );
      case AppTone.neutral:
        return ToneColors(
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurface,
          icon: Icons.info_outline,
        );
    }
  }
}
