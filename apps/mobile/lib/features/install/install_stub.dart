/// How this device can add the app to its home screen. Only the web build can;
/// everywhere else (the Android app, tests) this is always [InstallKind.none].
enum InstallKind {
  /// Nothing to offer: already installed, or the browser cannot install.
  none,

  /// The browser gave us its install prompt (Chrome, Edge, Samsung Internet).
  prompt,

  /// iPhone or iPad: install is manual (Share, then Add to Home Screen).
  ios,

  /// Firefox on Android: install is manual (menu, then Install or Add to Home screen).
  firefox,
}

InstallKind currentInstallKind() => InstallKind.none;

/// Shows the browser's own install dialog. Returns true if the rider accepted.
Future<bool> promptInstall() async => false;
