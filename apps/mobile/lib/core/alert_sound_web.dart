import "dart:js_interop";

// Defined in web/alert_sound.js. A short two-note chime made with Web Audio.
@JS("airpoolSound.play")
external void _play();

void playAlertSound() {
  try {
    _play();
  } catch (_) {
    // A browser that blocks audio just stays quiet.
  }
}
