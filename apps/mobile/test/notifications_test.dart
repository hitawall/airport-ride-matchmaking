import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/core/notifications.dart";

class _Controller extends NotificationController {
  _Controller(super.ref) : super(enabled: false);

  @override
  String get currentPath => "/home";

  void show(InAppAlert alert) => state = state.copyWith(alert: alert);
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

void main() {
  test("someone ending a match raises one alert offering to search again", () async {
    late NotificationController controller;
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(_EndedApi()),
        notificationsProvider.overrideWith((ref) => controller = _Controller(ref)),
      ],
    );
    addTearDown(container.dispose);
    container.read(notificationsProvider);

    await controller.poll();
    final alert = container.read(notificationsProvider).alert;
    expect(alert, isNotNull);
    expect(alert!.title, "Match ended");
    expect(alert.message, contains("Asha"));
    expect(alert.route, "/resume-trip");

    // The same ended match never alerts twice, even after dismissing.
    controller.dismissAlert();
    await controller.poll();
    expect(container.read(notificationsProvider).alert, isNull);
  });

  test("badge count adds unread messages and incoming likes", () {
    const state = NotificationState(unreadByMatch: {"a": 2, "b": 1}, incomingLikes: 3);
    expect(state.unreadTotal, 3);
    expect(state.badgeCount, 6);
    expect(const NotificationState().badgeCount, 0);
  });

  testWidgets("an alert floats over the screen and can be dismissed", (tester) async {
    late _Controller controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith((ref) => controller = _Controller(ref)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NotificationHost(child: Scaffold(body: Text("page"))),
        ),
      ),
    );
    expect(find.text("New message"), findsNothing);

    controller.show(
      const InAppAlert(id: 1, title: "New message", message: "Asha sent you a message.", actionLabel: "Open chat", route: "/chat/1"),
    );
    await tester.pump();
    expect(find.text("New message"), findsOneWidget);
    expect(find.text("Asha sent you a message."), findsOneWidget);
    expect(find.text("Open chat"), findsOneWidget);

    await tester.tap(find.byTooltip("Dismiss"));
    await tester.pump();
    expect(find.text("New message"), findsNothing);
  });
}
