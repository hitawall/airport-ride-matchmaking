import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/core/ui/trolley_bags.dart";
import "package:mobile/data/airports.dart";
import "package:mobile/data/models.dart";
import "package:mobile/features/ride_request/create_ride_request_screen.dart";
import "support/memory_storage.dart";

void main() {
  createFormTests();
  group("trolley bag wording", () {
    test("is plain for every count", () {
      expect(trolleyBagsLabel(0), "No trolley bags");
      expect(trolleyBagsLabel(1), "1 trolley bag");
      expect(trolleyBagsLabel(3), "3 trolley bags");
      expect(trolleyBagsLabel(4), "3+ trolley bags");
      expect(trolleyBagsLabel(6), "3+ trolley bags", reason: "older trips with more bags read the same");
      expect(trolleyBagsLabel(null), "Luggage not given");
    });
  });

  group("models read trolley bags", () {
    test("candidate and trip carry the count, older trips have none", () {
      final candidate = Candidate.fromJson({
        "id": "r1",
        "user_id": "u1",
        "display_name": "Asha",
        "gender": "female",
        "flight_arrival_at": "2026-12-01T10:00:00.000Z",
        "destination_locality_label": "Indiranagar",
        "trolley_bags": 2,
      });
      expect(candidate.trolleyBags, 2);

      final trip = RideRequest.fromJson({
        "id": "r1",
        "status": "open",
        "flightArrivalAt": "2026-12-01T10:00:00.000Z",
        "destinationLocalityLabel": "Indiranagar",
        "trolleyBags": 0,
      });
      expect(trip.trolleyBags, 0);

      final old = RideRequest.fromJson({
        "id": "r2",
        "status": "open",
        "flightArrivalAt": "2026-12-01T10:00:00.000Z",
        "destinationLocalityLabel": "Indiranagar",
      });
      expect(old.trolleyBags, isNull);
    });
  });

  testWidgets("the badge shows the count in words", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Column(children: [TrolleyBagsBadge(count: 2), TrolleyBagsBadge(count: 0, large: true)]),
        ),
      ),
    );
    expect(find.text("2 trolley bags"), findsOneWidget);
    expect(find.text("No trolley bags"), findsOneWidget);
    expect(find.byIcon(Icons.luggage_outlined), findsNWidgets(2));
  });
}

/// Records any trip the form tries to create.
class _RecordingApi extends ApiClient {
  final posts = <String>[];

  @override
  Future<dynamic> get(String path) async {
    if (path == "/api/profile/me") return {"displayName": "Asha", "gender": "female"};
    throw ApiException(404, "Not found");
  }

  @override
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    posts.add(path);
    return {"id": "r1"};
  }
}

const _catalog = AirportCatalog(
  defaultAirportCode: "BLR",
  airports: [
    Airport(
      code: "BLR",
      name: "Kempegowda International Airport",
      city: "Bengaluru",
      lat: 13.1986,
      lng: 77.7066,
      terminals: [Terminal(code: "T1", name: "Terminal 1")],
      localities: [Locality("Indiranagar", 12.9719, 77.6412)],
    ),
  ],
);

void createFormTests() {
  testWidgets("the create form insists on a trolley bag count", (tester) async {
    tester.view.physicalSize = const Size(412, 1800) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final api = _RecordingApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          secureStorageProvider.overrideWithValue(MemoryStorage()),
          airportCatalogProvider.overrideWith((ref) async => _catalog),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const CreateRideRequestScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("How much luggage do you have?"), findsOneWidget);
    await tester.tap(find.text("Find a match"));
    await tester.pumpAndSettle();
    expect(find.text("Tell us how many trolley bags you have (0 is fine)"), findsOneWidget);
    expect(api.posts, isEmpty);

    expect(find.widgetWithText(ChoiceChip, "3+"), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, "4"), findsNothing);
    expect(find.widgetWithText(ChoiceChip, "6"), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, "2"));
    await tester.pumpAndSettle();
    expect(find.text("Tell us how many trolley bags you have (0 is fine)"), findsNothing);
  });
}
