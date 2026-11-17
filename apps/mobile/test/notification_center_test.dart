import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/core/notifications.dart";
import "package:mobile/features/notifications/notifications_screen.dart";
import "support/memory_storage.dart";

class _Controller extends NotificationController {
  _Controller(super.ref, {String userId = "u1"}) : super(enabled: false, userId: userId);

  @override
  String get currentPath => "/home";
}

/// What the server reports; tests change it between polls.
class _Api extends ApiClient {
  Map<String, dynamic> body = {
    "unreadMessages": [],
    "incomingLikes": null,
    "mutualMatches": [
      {"id": "m1", "counterpartName": "Asha"},
    ],
    "endedMatches": [],
  };

  @override
  Future<dynamic> get(String path) async => body;
}

ProviderContainer _container(_Api api, MemoryStorage storage, void Function(_Controller) onCreate, {String userId = "u1"}) {
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      secureStorageProvider.overrideWithValue(storage),
      notificationsProvider.overrideWith((ref) {
        final c = _Controller(ref, userId: userId);
        onCreate(c);
        return c;
      }),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test("a banner that was shown once does not come back at the next login", () async {
    final storage = MemoryStorage();
    final api = _Api();

    late _Controller first;
    final one = _container(api, storage, (c) => first = c);
    one.read(notificationsProvider);
    await first.restore();
    await first.poll();
    expect(one.read(notificationsProvider).alert?.title, "It's a match!");
    expect(one.read(notificationsProvider).unreadItems, 1);
    first.dismissAlert(); // crossed
    await Future<void>.delayed(Duration.zero);

    // Signing in again later: a new controller reading the same device storage.
    late _Controller second;
    final two = _container(api, storage, (c) => second = c);
    two.read(notificationsProvider);
    await second.restore();
    await second.poll();
    expect(two.read(notificationsProvider).alert, isNull);
    expect(two.read(notificationsProvider).items, hasLength(1));
    expect(two.read(notificationsProvider).unreadItems, 1, reason: "still unread under the bell");
  });

  test("a different person on the same device does not see it", () async {
    final storage = MemoryStorage();
    final api = _Api();
    late _Controller first;
    final one = _container(api, storage, (c) => first = c);
    one.read(notificationsProvider);
    await first.restore();
    await first.poll();
    expect(one.read(notificationsProvider).items, hasLength(1));
    await Future<void>.delayed(Duration.zero);

    late _Controller other;
    final two = _container(api, storage, (c) => other = c, userId: "u2");
    two.read(notificationsProvider);
    await other.restore();
    expect(two.read(notificationsProvider).items, isEmpty);
  });

  test("opening the list marks everything read", () async {
    late _Controller controller;
    final container = _container(_Api(), MemoryStorage(), (c) => controller = c);
    container.read(notificationsProvider);
    await controller.poll();
    expect(container.read(notificationsProvider).unreadItems, 1);
    controller.markAllRead();
    expect(container.read(notificationsProvider).unreadItems, 0);
    expect(container.read(notificationsProvider).items, hasLength(1), reason: "read items stay in the list");
  });

  test("opening a banner marks its notification read", () async {
    late _Controller controller;
    final container = _container(_Api(), MemoryStorage(), (c) => controller = c);
    container.read(notificationsProvider);
    await controller.poll();
    controller.openAlert(container.read(notificationsProvider).alert!);
    expect(container.read(notificationsProvider).alert, isNull);
    expect(container.read(notificationsProvider).unreadItems, 0);
  });

  test("messages announce again after the chat was read, but not on every poll", () async {
    final api = _Api()
      ..body = {
        "unreadMessages": [
          {"matchId": "m9", "count": 1, "senderName": "Ravi"},
        ],
        "incomingLikes": null,
        "mutualMatches": [],
        "endedMatches": [],
      };
    late _Controller controller;
    final container = _container(api, MemoryStorage(), (c) => controller = c);
    container.read(notificationsProvider);

    await controller.poll();
    expect(container.read(notificationsProvider).alert?.title, "New message");
    controller.dismissAlert();
    await controller.poll();
    expect(container.read(notificationsProvider).alert, isNull, reason: "same unread count is not news");

    api.body = {...api.body, "unreadMessages": []}; // read it
    await controller.poll();
    expect(container.read(notificationsProvider).unreadItems, 0);

    api.body = {
      ...api.body,
      "unreadMessages": [
        {"matchId": "m9", "count": 1, "senderName": "Ravi"},
      ],
    };
    await controller.poll();
    expect(container.read(notificationsProvider).alert?.title, "New message");
  });

  testWidgets("the bell shows the unread count and the list reads everything", (tester) async {
    late _Controller controller;
    final api = _Api();
    final storage = MemoryStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          secureStorageProvider.overrideWithValue(storage),
          notificationsProvider.overrideWith((ref) => controller = _Controller(ref)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(appBar: AppBar(actions: const [NotificationBell()]), body: const SizedBox()),
        ),
      ),
    );
    await controller.poll();
    await tester.pump();
    expect(find.text("1"), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          secureStorageProvider.overrideWithValue(storage),
          notificationsProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("It's a match!"), findsOneWidget);
    expect(controller.state.unreadItems, 0, reason: "opening the list reads everything");
  });
}
