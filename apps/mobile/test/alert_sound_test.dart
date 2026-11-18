import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mobile/core/alert_sound.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/core/notifications.dart";
import "support/memory_storage.dart";

class _Controller extends NotificationController {
  _Controller(super.ref) : super(enabled: false);

  @override
  String get currentPath => "/home";
}

class _EndedApi extends ApiClient {
  @override
  Future<dynamic> get(String path) async => {
    "unreadMessages": [],
    "incomingLikes": null,
    "mutualMatches": [],
    "endedMatches": [
      {"id": "m1", "counterpartName": "Asha"},
    ],
  };
}

Future<int> _chimes({required MemoryStorage storage, int polls = 1}) async {
  var played = 0;
  late NotificationController controller;
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(_EndedApi()),
      secureStorageProvider.overrideWithValue(storage),
      alertSoundPlayerProvider.overrideWithValue(() => played++),
      notificationsProvider.overrideWith((ref) => controller = _Controller(ref)),
    ],
  );
  addTearDown(container.dispose);
  container.read(notificationsProvider);
  for (var i = 0; i < polls; i++) {
    await controller.poll();
    await Future<void>.delayed(Duration.zero);
  }
  return played;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("a new notification plays the sound once, not again for the same event", () async {
    expect(await _chimes(storage: MemoryStorage(), polls: 3), 1);
  });

  test("turning the sound off in Settings keeps it quiet", () async {
    final storage = MemoryStorage();
    await storage.writeString(alertSoundStorageKey, "off");
    expect(await _chimes(storage: storage), 0);
  });
}
