import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/data/airports.dart";
import "package:mobile/features/ride_request/create_ride_request_screen.dart";
import "support/memory_storage.dart";

class _Api extends ApiClient {
  _Api(this.photoUrl);

  final String? photoUrl;

  @override
  Future<dynamic> get(String path) async {
    if (path == "/api/profile/me") return {"displayName": "Asha", "gender": "female", "profilePhotoUrl": photoUrl};
    throw ApiException(404, "Not found");
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

Future<void> _open(WidgetTester tester, String? photoUrl) async {
  tester.view.physicalSize = const Size(412, 2400) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_Api(photoUrl)),
        secureStorageProvider.overrideWithValue(MemoryStorage()),
        airportCatalogProvider.overrideWith((ref) async => _catalog),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const CreateRideRequestScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("someone without a photo can still search, with a gentle nudge to add one", (tester) async {
    await _open(tester, null);
    expect(find.text("Add a photo (optional)"), findsOneWidget);
    expect(find.textContaining("helps you get better matches"), findsOneWidget);
    expect(find.text("Find a match"), findsOneWidget);
  });

  testWidgets("no nudge when there already is a photo", (tester) async {
    await _open(tester, "https://example.com/p.jpg");
    expect(find.text("Add a photo (optional)"), findsNothing);
  });
}
