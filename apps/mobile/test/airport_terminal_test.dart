import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/data/airports.dart";
import "package:mobile/features/ride_request/create_ride_request_screen.dart";

const _blr = Airport(
  code: "BLR",
  name: "Kempegowda International Airport",
  city: "Bengaluru",
  terminals: [Terminal(code: "T1", name: "Terminal 1"), Terminal(code: "T2", name: "Terminal 2")],
  localities: [Locality("Koramangala", 12.9, 77.6)],
);

const _del = Airport(
  code: "DEL",
  name: "Indira Gandhi International Airport",
  city: "Delhi",
  terminals: [Terminal(code: "T3", name: "Terminal 3")],
  localities: [Locality("Dwarka", 28.5, 77.0)],
);

Widget _app(AirportCatalog catalog) => ProviderScope(
  overrides: [airportCatalogProvider.overrideWith((ref) async => catalog)],
  child: MaterialApp(theme: AppTheme.light(), home: const CreateRideRequestScreen()),
);

void main() {
  test("airportTerminalLabel reads naturally and copes with old requests", () {
    expect(airportTerminalLabel("BLR", "T2"), "BLR · Terminal 2");
    expect(airportTerminalLabel("BLR", null), "BLR");
    expect(airportTerminalLabel("DEL", "Arrivals"), "DEL · Arrivals");
  });

  testWidgets("with one airport the airport is fixed and the terminal must be chosen", (tester) async {
    await tester.pumpWidget(_app(const AirportCatalog(airports: [_blr], defaultAirportCode: "BLR")));
    await tester.pumpAndSettle();

    expect(find.text("Terminal 1"), findsOneWidget);
    expect(find.text("Terminal 2"), findsOneWidget);
    expect(find.textContaining("Kempegowda International Airport (BLR)"), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<Airport>), findsNothing);

    await tester.tap(find.text("Find a match"));
    await tester.pumpAndSettle();
    expect(find.text("Choose the terminal you arrive at"), findsOneWidget);

    await tester.tap(find.text("Terminal 2"));
    await tester.pumpAndSettle();
    expect(find.text("Choose the terminal you arrive at"), findsNothing);
  });

  testWidgets("a second airport shows a picker and changing it resets the terminal", (tester) async {
    await tester.pumpWidget(_app(const AirportCatalog(airports: [_blr, _del], defaultAirportCode: "BLR")));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<Airport>), findsOneWidget);
    await tester.tap(find.text("Terminal 1"));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<Airport>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Delhi (DEL)").last);
    await tester.pumpAndSettle();

    expect(find.text("Terminal 3"), findsOneWidget);
    expect(find.text("Terminal 1"), findsNothing);
  });
}
