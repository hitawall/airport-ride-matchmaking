import "google_sign_in.dart";

/// Google sign-in is built for the web app only for now (the Android app needs
/// its own Google client, which waits for the final package id).
const googleSignInSupported = false;

Future<GoogleTokenResult> requestGoogleAccessToken(String clientId) async =>
    const GoogleTokenResult(error: "Google sign-in isn't available in this app yet.");
