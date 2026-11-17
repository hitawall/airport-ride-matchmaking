import "dart:convert";
import "dart:js_interop";
import "google_sign_in.dart";

const googleSignInSupported = true;

// Defined in web/google_sign_in.js. Opens Google's sign-in popup.
@JS("airpoolGoogle.requestAccessToken")
external JSPromise<JSString> _requestAccessToken(JSString clientId);

Future<GoogleTokenResult> requestGoogleAccessToken(String clientId) async {
  try {
    final json = jsonDecode((await _requestAccessToken(clientId.toJS).toDart).toDart) as Map<String, dynamic>;
    if (json["cancelled"] == true) return const GoogleTokenResult(cancelled: true);
    final token = json["accessToken"] as String?;
    if (token != null && token.isNotEmpty) return GoogleTokenResult(accessToken: token);
    return GoogleTokenResult(error: json["error"] as String? ?? "Google sign-in didn't finish. Please try again.");
  } catch (_) {
    return const GoogleTokenResult(error: "Google sign-in isn't available right now.");
  }
}
