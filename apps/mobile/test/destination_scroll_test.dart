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
      localities: [for (var i = 0; i < 40; i++) Locality("Area ${i.toString().padLeft(2, "0")}", 12.9 + i / 1000, 77.6)],
    ),
  ],
);

void main() {
  testWidgets("the destination suggestions scroll without closing the keyboard", (tester) async {
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

    final field = find.widgetWithText(TextField, "Destination area");
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.enterText(field, "Area");
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);

    final list = find.byType(ListView);
    expect(list, findsOneWidget);
    expect(find.text("Area 00"), findsOneWidget);

    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text("Area 00"), findsNothing, reason: "the list scrolled down");
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue, reason: "the keyboard stayed open");
  });
}
