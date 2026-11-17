import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/features/onboarding/email_entry_screen.dart";
import "package:mobile/features/onboarding/google_sign_in.dart";
import "support/memory_storage.dart";

class _Api extends ApiClient {
  final posts = <String>[];
  bool isNewUser = true;

  @override
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    posts.add("$path ${body?["accessToken"]}");
    if (path == "/api/auth/google") return {"token": "t", "userId": "u1", "isNewUser": isNewUser};
    throw ApiException(404, "Not found");
  }
}

Future<(_Api, String Function())> _open(
  WidgetTester tester, {
  required bool enabled,
  required GoogleTokenResult result,
  bool isNewUser = true,
}) async {
  tester.view.physicalSize = const Size(412, 1400) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final api = _Api()..isNewUser = isNewUser;
  var location = "/email";
  final router = GoRouter(
    initialLocation: "/email",
    routes: [
      GoRoute(path: "/email", builder: (context, state) => const EmailEntryScreen()),
      GoRoute(path: "/profile-setup", builder: (context, state) => const Text("profile setup")),
      GoRoute(path: "/home", builder: (context, state) => const Text("home")),
      GoRoute(path: "/", builder: (context, state) => const Text("welcome")),
    ],
  );
  router.routerDelegate.addListener(() => location = router.routerDelegate.currentConfiguration.uri.path);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        secureStorageProvider.overrideWithValue(MemoryStorage()),
        googleSignInEnabledProvider.overrideWithValue(enabled),
        googleTokenRequesterProvider.overrideWithValue(() async => result),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (api, () => location);
}

void main() {
  testWidgets("no Google button until a client ID is set up", (tester) async {
    await _open(tester, enabled: false, result: const GoogleTokenResult(cancelled: true));
    expect(find.text("Continue with Google"), findsNothing);
    expect(find.text("Send code"), findsOneWidget);
  });

  testWidgets("a new person signs in with Google and goes to profile setup", (tester) async {
    final (api, location) = await _open(tester, enabled: true, result: const GoogleTokenResult(accessToken: "tok123"));
    await tester.ensureVisible(find.text("Continue with Google"));
    await tester.tap(find.text("Continue with Google"));
    await tester.pumpAndSettle();
    expect(api.posts, ["/api/auth/google tok123"]);
    expect(location(), "/profile-setup");
  });

  testWidgets("someone who already has an account goes home", (tester) async {
    final (_, location) = await _open(
      tester,
      enabled: true,
      result: const GoogleTokenResult(accessToken: "tok123"),
      isNewUser: false,
    );
    await tester.ensureVisible(find.text("Continue with Google"));
    await tester.tap(find.text("Continue with Google"));
    await tester.pumpAndSettle();
    expect(location(), "/home");
  });

  testWidgets("closing the popup does nothing, a failure says why", (tester) async {
    final (api, location) = await _open(tester, enabled: true, result: const GoogleTokenResult(cancelled: true));
    await tester.ensureVisible(find.text("Continue with Google"));
    await tester.tap(find.text("Continue with Google"));
    await tester.pumpAndSettle();
    expect(api.posts, isEmpty);
    expect(location(), "/email");

    final (_, location2) = await _open(
      tester,
      enabled: true,
      result: const GoogleTokenResult(error: "Your browser blocked the Google window."),
    );
    await tester.ensureVisible(find.text("Continue with Google"));
    await tester.tap(find.text("Continue with Google"));
    await tester.pumpAndSettle();
    expect(find.text("Your browser blocked the Google window."), findsOneWidget);
    expect(location2(), "/email");
  });
}
