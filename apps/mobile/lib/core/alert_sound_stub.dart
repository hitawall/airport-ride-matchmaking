import "package:flutter/services.dart";

/// The phone's own short alert sound (the app on Android and iOS).
void playAlertSound() {
  SystemSound.play(SystemSoundType.alert);
}
