import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/data/models.dart";
import "package:mobile/features/matching/match_review_screen.dart";
import "support/memory_storage.dart";

class _Api extends ApiClient {
  final posts = <Map<String, dynamic>>[];

  @override
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    posts.add({"path": path, ...?body});
    return {"id": "m-${posts.length}", "status": "proposed_by_a"};
  }
}

Candidate _person(String id, String name, int bags) => Candidate(
  rideRequestId: id,
  userId: "u-$id",
  displayName: name,
  gender: "female",
  flightArrivalAt: DateTime.utc(2026, 12, 1, 10),
  destinationLocalityLabel: "Indiranagar",
  airportCode: "BLR",
  terminal: "T1",
  trolleyBags: bags,
);

Future<(_Api, String Function())> _open(WidgetTester tester, List<Candidate> people) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final api = _Api();
  var location = "/match-review/r1";
  final router = GoRouter(
    initialLocation: "/match-review/r1",
    routes: [
      GoRoute(
        path: "/match-review/:id",
        builder: (context, state) => MatchReviewScreen(rideRequestId: "r1", candidates: people),
      ),
      GoRoute(path: "/awaiting-match/:id", builder: (context, state) => const Text("awaiting")),
      GoRoute(path: "/mutual-match/:id", builder: (context, state) => const Text("mutual")),
      GoRoute(path: "/home", builder: (context, state) => const Text("home")),
    ],
  );
  router.routerDelegate.addListener(() => location = router.routerDelegate.currentConfiguration.uri.path);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        secureStorageProvider.overrideWithValue(MemoryStorage()),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (api, () => location);
}

void main() {
  final people = [_person("a", "Asha", 1), _person("b", "Ravi", 2), _person("c", "Meera", 0)];

  testWidgets("everyone can be browsed before anyone is liked", (tester) async {
    final (api, _) = await _open(tester, people);
    expect(find.text("1 of 3"), findsOneWidget);
    // The whole group is visible at a glance, with luggage for comparing.
    expect(find.text("Ravi"), findsWidgets);
    expect(find.text("Meera"), findsWidgets);

    await tester.tap(find.byTooltip("Next person"));
    await tester.pumpAndSettle();
    expect(find.text("2 of 3"), findsOneWidget);
    await tester.tap(find.byTooltip("Next person"));
    await tester.pumpAndSettle();
    expect(find.text("3 of 3"), findsOneWidget);
    await tester.tap(find.byTooltip("Previous person"));
    await tester.pumpAndSettle();
    expect(find.text("2 of 3"), findsOneWidget);

    expect(api.posts, isEmpty, reason: "browsing never likes or passes anyone");
  });

  testWidgets("the strip jumps to a person", (tester) async {
    await _open(tester, people);
    await tester.tap(find.text("Meera").first);
    await tester.pumpAndSettle();
    expect(find.text("3 of 3"), findsOneWidget);
  });

  testWidgets("liking one person does not decide the others, and moves on to the next undecided", (tester) async {
    final (api, location) = await _open(tester, people);
    await tester.tap(find.byKey(const ValueKey("like-button")));
    await tester.pumpAndSettle();
    expect(api.posts.single, {"path": "/api/matches", "rideRequestId": "r1", "candidateRideRequestId": "a", "action": "like"});
    expect(find.text("2 of 3"), findsOneWidget);
    expect(location(), "/match-review/r1", reason: "still choosing among the others");

    // Back on the first person, the choice is remembered and cannot be repeated.
    await tester.tap(find.byTooltip("Previous person"));
    await tester.pumpAndSettle();
    expect(find.text("You liked Asha"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("like-button")), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(api.posts, hasLength(1));
  });

  testWidgets("once everyone has an answer the rider is taken to the waiting screen", (tester) async {
    final (api, location) = await _open(tester, people);
    await tester.tap(find.byKey(const ValueKey("pass-button")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("like-button")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("pass-button")));
    await tester.pumpAndSettle();
    expect(api.posts.map((p) => p["action"]), ["pass", "like", "pass"]);
    expect(location(), "/awaiting-match/r1");
  });
}
