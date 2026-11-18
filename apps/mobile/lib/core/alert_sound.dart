import "package:flutter_riverpod/flutter_riverpod.dart";
import "alert_sound_stub.dart" if (dart.library.js_interop) "alert_sound_web.dart" as impl;

/// Where the "Notification sound" switch in Settings is remembered. Anything
/// other than "off" (including never having been set) means the sound is on.
const alertSoundStorageKey = "alert_sound";

/// Plays the sound for a new notification. Overridden in tests.
final alertSoundPlayerProvider = Provider<void Function()>((ref) => impl.playAlertSound);
