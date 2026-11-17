import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/app_config.dart";
import "google_sign_in_stub.dart" if (dart.library.js_interop) "google_sign_in_web.dart" as impl;

/// What came back from Google's sign-in popup: a token to send to our API, or
/// a plain-words reason there is none. [cancelled] means the person closed the
/// popup, which needs no message.
class GoogleTokenResult {
  const GoogleTokenResult({this.accessToken, this.error, this.cancelled = false});

  final String? accessToken;
  final String? error;
  final bool cancelled;
}

/// Whether to show "Continue with Google": needs a client ID from the owner
/// and a build that can open the popup.
final googleSignInEnabledProvider = Provider<bool>((ref) => AppConfig.hasGoogleSignIn && impl.googleSignInSupported);

/// Opens Google's popup. Overridden in tests.
final googleTokenRequesterProvider = Provider<Future<GoogleTokenResult> Function()>(
  (ref) =>
      () => impl.requestGoogleAccessToken(AppConfig.googleClientId),
);
