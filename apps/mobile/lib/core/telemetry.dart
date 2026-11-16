import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "api_client.dart";

/// Crash reports and the "app opened" signal. Both go to our own API (which
/// forwards to the analytics and error tools, if configured), so no third-party
/// SDK or keys live in the app. Nothing personal is sent: no name, email, phone
/// or message text. Users can turn it off in Settings.
class Telemetry {
  Telemetry._();

  static const _prefKey = "telemetry_enabled";
  static const _storage = FlutterSecureStorage();

  /// Set in release builds from pubspec.yaml; see .github/scripts/app-defines.sh.
  static const appVersion = String.fromEnvironment("APP_VERSION", defaultValue: "dev");

  static bool _enabled = true;
  static int _errorsThisRun = 0;
  static const _maxErrorsPerRun = 5;
  static bool _sending = false;
  static bool _openedReported = false;

  static bool get enabled => _enabled;

  /// Loads the saved choice. Safe to call where storage is unavailable (tests).
  static Future<void> init() async {
    try {
      _enabled = (await _storage.read(key: _prefKey)) != "false";
    } catch (_) {
      _enabled = true;
    }
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      await _storage.write(key: _prefKey, value: value.toString());
    } catch (_) {
      // The in-memory choice still applies for this run.
    }
  }

  static String get platform {
    if (kIsWeb) return "web";
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => "android",
      TargetPlatform.iOS => "ios",
      _ => "other",
    };
  }

  /// Once per app run, after sign-in. Used for daily and weekly active users.
  static Future<void> reportAppOpened(ApiClient api) async {
    if (!_enabled || _openedReported) return;
    _openedReported = true;
    try {
      await api.post("/api/events", {"event": "app_opened", "platform": platform, "appVersion": appVersion});
    } catch (_) {
      // Telemetry never surfaces errors to the user.
    }
  }

  static String _clip(String text, int max) => text.length <= max ? text : text.substring(0, max);

  /// Sends one unhandled error (capped per run). Never throws, never loops.
  static Future<void> reportError(Object error, StackTrace? stack) async {
    if (!_enabled || _sending || _errorsThisRun >= _maxErrorsPerRun) return;
    if (error is ApiException) return; // expected, already shown to the user
    _sending = true;
    _errorsThisRun++;
    try {
      await ApiClient().post("/api/client-errors", {
        "name": _clip(error.runtimeType.toString(), 100),
        "message": _clip(error.toString(), 900),
        if (stack != null) "stack": _clip(stack.toString(), 3500),
        "platform": platform,
        "appVersion": appVersion,
      });
    } catch (_) {
      // Dropped on purpose.
    } finally {
      _sending = false;
    }
  }
}
