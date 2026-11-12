import "package:material_ui/material_ui.dart";

/// A warm, confident, dating-app-inspired visual identity: cream background,
/// a bold coral primary, a deep plum secondary, generous rounding, and a
/// heavier-weight type scale for an editorial, confident feel. Takes
/// inspiration from the genre (Hinge, etc.) without copying any specific
/// app's trademarked brand assets or custom typeface.
class AppTheme {
  AppTheme._();

  static const cream = Color(0xFFFBF3E7);
  static const surfaceWhite = Color(0xFFFFFDF9);
  static const coral = Color(0xFFE8604B);
  static const plum = Color(0xFF4A2545);
  static const ink = Color(0xFF241F21);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: coral,
      brightness: Brightness.light,
    ).copyWith(
      primary: coral,
      onPrimary: Colors.white,
      secondary: plum,
      onSecondary: Colors.white,
      surface: surfaceWhite,
      onSurface: ink,
      surfaceContainerHighest: const Color(0xFFF2E6D6),
      error: const Color(0xFFC13B2A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: cream,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          fontSize: 23,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.5,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: ink),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: coral,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: plum,
          side: const BorderSide(color: plum),
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: plum),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: coral, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFC13B2A), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: surfaceWhite,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF2E6D6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFEADFCB)),
      iconTheme: const IconThemeData(color: plum),
    );
  }
}
