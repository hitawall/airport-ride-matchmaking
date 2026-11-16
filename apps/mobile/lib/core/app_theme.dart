import "package:google_fonts/google_fonts.dart";
import "package:material_ui/material_ui.dart";
import "ui/tokens.dart";

/// Nature / road / sky accents that sit beside the Material color scheme.
/// Read with `context.appColors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.moss,
    required this.mossContainer,
    required this.onMossContainer,
    required this.sky,
    required this.skyContainer,
    required this.onSkyContainer,
    required this.amber,
    required this.amberContainer,
    required this.onAmberContainer,
    required this.asphalt,
  });

  final Color moss;
  final Color mossContainer;
  final Color onMossContainer;
  final Color sky;
  final Color skyContainer;
  final Color onSkyContainer;
  final Color amber;
  final Color amberContainer;
  final Color onAmberContainer;
  final Color asphalt;

  @override
  AppColors copyWith({
    Color? moss,
    Color? mossContainer,
    Color? onMossContainer,
    Color? sky,
    Color? skyContainer,
    Color? onSkyContainer,
    Color? amber,
    Color? amberContainer,
    Color? onAmberContainer,
    Color? asphalt,
  }) {
    return AppColors(
      moss: moss ?? this.moss,
      mossContainer: mossContainer ?? this.mossContainer,
      onMossContainer: onMossContainer ?? this.onMossContainer,
      sky: sky ?? this.sky,
      skyContainer: skyContainer ?? this.skyContainer,
      onSkyContainer: onSkyContainer ?? this.onSkyContainer,
      amber: amber ?? this.amber,
      amberContainer: amberContainer ?? this.amberContainer,
      onAmberContainer: onAmberContainer ?? this.onAmberContainer,
      asphalt: asphalt ?? this.asphalt,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      moss: Color.lerp(moss, other.moss, t)!,
      mossContainer: Color.lerp(mossContainer, other.mossContainer, t)!,
      onMossContainer: Color.lerp(onMossContainer, other.onMossContainer, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
      skyContainer: Color.lerp(skyContainer, other.skyContainer, t)!,
      onSkyContainer: Color.lerp(onSkyContainer, other.onSkyContainer, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberContainer: Color.lerp(amberContainer, other.amberContainer, t)!,
      onAmberContainer: Color.lerp(onAmberContainer, other.onAmberContainer, t)!,
      asphalt: Color.lerp(asphalt, other.asphalt, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

/// "Golden hour on the airport road": warm cream paper, coral as the headlight
/// call to action, plum for depth, with moss / sky / amber accents. Fraunces
/// (a soft serif) carries headlines, DM Sans carries the UI. See DESIGN.md.
class AppTheme {
  AppTheme._();

  static const cream = Color(0xFFFBF3E7);
  static const surfaceWhite = Color(0xFFFFFDF9);
  static const coral = Color(0xFFE8604B);
  static const plum = Color(0xFF4A2545);
  static const ink = Color(0xFF241F21);
  static const mutedInk = Color(0xFF6B5F63);
  static const line = Color(0xFFEADFCB);
  static const sand = Color(0xFFF2E6D6);
  static const danger = Color(0xFFC13B2A);

  static const _appColors = AppColors(
    moss: Color(0xFF4F7A52),
    mossContainer: Color(0xFFDDEBD9),
    onMossContainer: Color(0xFF1F3A22),
    sky: Color(0xFF5B9BBF),
    skyContainer: Color(0xFFDCEBF4),
    onSkyContainer: Color(0xFF1B3B50),
    amber: Color(0xFFE9A23B),
    amberContainer: Color(0xFFFBEBCB),
    onAmberContainer: Color(0xFF5A3A07),
    asphalt: Color(0xFF2E2A2D),
  );

  static TextStyle _display(double size, {FontWeight weight = FontWeight.w600, double height = 1.15}) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: -0.5,
      color: ink,
    );
  }

  static TextStyle _ui(
    double size, {
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
    double letterSpacing = 0,
    Color color = ink,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextTheme _textTheme() {
    return TextTheme(
      displayLarge: _display(44, height: 1.1),
      displayMedium: _display(36, height: 1.12),
      displaySmall: _display(30),
      headlineLarge: _display(32),
      headlineMedium: _display(28),
      headlineSmall: _display(24, height: 1.2),
      titleLarge: _ui(20, weight: FontWeight.w700, height: 1.3),
      titleMedium: _ui(16, weight: FontWeight.w700, height: 1.35),
      titleSmall: _ui(14, weight: FontWeight.w700, height: 1.35),
      bodyLarge: _ui(16),
      bodyMedium: _ui(14),
      bodySmall: _ui(12, height: 1.4, color: mutedInk),
      labelLarge: _ui(15, weight: FontWeight.w700, height: 1.2),
      labelMedium: _ui(12, weight: FontWeight.w600, height: 1.2),
      labelSmall: _ui(11, weight: FontWeight.w600, height: 1.2, letterSpacing: 0.4),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: coral, brightness: Brightness.light).copyWith(
      primary: coral,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFBDDD5),
      onPrimaryContainer: const Color(0xFF5A1A10),
      secondary: plum,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFEBDDEA),
      onSecondaryContainer: plum,
      tertiary: _appColors.moss,
      onTertiary: Colors.white,
      tertiaryContainer: _appColors.mossContainer,
      onTertiaryContainer: _appColors.onMossContainer,
      surface: surfaceWhite,
      onSurface: ink,
      onSurfaceVariant: mutedInk,
      surfaceContainerHighest: sand,
      outline: const Color(0xFFBFB2A3),
      outlineVariant: line,
      error: danger,
      onError: Colors.white,
      errorContainer: const Color(0xFFFADAD4),
      onErrorContainer: const Color(0xFF5C150C),
    );

    final textTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: cream,
      textTheme: textTheme,
      extensions: const [_appColors],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: line),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: coral,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 54),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16, color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: plum,
          side: const BorderSide(color: plum, width: 1.5),
          minimumSize: const Size(64, 54),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: plum,
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: plum),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        border: _inputBorder(line, 1),
        enabledBorder: _inputBorder(line, 1),
        disabledBorder: _inputBorder(line, 1),
        focusedBorder: _inputBorder(coral, 2),
        errorBorder: _inputBorder(danger, 1.5),
        focusedErrorBorder: _inputBorder(danger, 2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: textTheme.bodyLarge?.copyWith(color: mutedInk),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: plum, fontWeight: FontWeight.w600),
        hintStyle: textTheme.bodyLarge?.copyWith(color: mutedInk.withValues(alpha: 0.7)),
        helperStyle: textTheme.bodySmall,
        helperMaxLines: 2,
        errorStyle: textTheme.bodySmall?.copyWith(color: danger, fontWeight: FontWeight.w600),
        errorMaxLines: 3,
        prefixIconColor: mutedInk,
        suffixIconColor: mutedInk,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: mutedInk),
        iconColor: plum,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceWhite,
        selectedColor: colorScheme.primaryContainer,
        side: const BorderSide(color: line),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        showCheckmark: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: _appColors.amber,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        insetPadding: const EdgeInsets.all(16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceWhite,
        modalBackgroundColor: surfaceWhite,
        showDragHandle: true,
        dragHandleColor: line,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : mutedInk,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? coral : sand,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? coral : line,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 3,
        shape: CircleBorder(),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: coral),
      dividerTheme: const DividerThemeData(color: line, space: 1),
      iconTheme: const IconThemeData(color: plum),
    );
  }
}
