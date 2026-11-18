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
  @override
  Future<dynamic> get(String path) async => {"displayName": "Asha", "gender": "female", "profilePhotoUrl": "https://example.com/p.jpg"};
}

final _catalog = AirportCatalog(
  defaultAirportCode: "BLR",
  airports: [
    Airport(
      code: "BLR",
      name: "Kempegowda International Airport",
      city: "Bengaluru",
      lat: 13.1986,
      lng: 77.7066,
      terminals: const [Terminal(code: "T1", name: "Terminal 1")],
      localities: [Locality("Indiranagar", 12.97, 77.64)],
    ),
  ],
);

void main() {
  testWidgets("the boarding pass scan and upload are not shown for now", (tester) async {
    tester.view.physicalSize = const Size(412, 915) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_Api()),
          secureStorageProvider.overrideWithValue(MemoryStorage()),
          airportCatalogProvider.overrideWith((ref) async => _catalog),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const CreateRideRequestScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(boardingPassEnabled, isFalse);
    expect(find.byTooltip("Scan boarding pass"), findsNothing);
    expect(find.textContaining("boarding pass"), findsNothing);
    expect(find.byIcon(Icons.upload_file_outlined), findsNothing);
  });
}
