/// Spacing scale shared by every screen. Use these instead of literals.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page gutter.
  static const double gutter = 24;

  /// Content never stretches wider than this on desktop browsers.
  static const double maxContentWidth = 480;
}

/// Corner radii: sm for chips/banners, md for inputs, lg for cards and sheets.
class AppRadii {
  AppRadii._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;
}
