import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/features/matching/fare_split.dart";
import "package:mobile/features/matching/fare_split_sheet.dart";

void main() {
  testWidgets("typing the fare shows each rider's share, with the not-enforced notice", (tester) async {
    final split = suggestFareSplit(
      airportLat: 13.1986,
      airportLng: 77.7066,
      riders: const [
        SplitRider(id: "me", name: "You", lat: 12.9352, lng: 77.6245), // Koramangala
        SplitRider(id: "them", name: "Ravi", lat: 12.9719, lng: 77.6412), // Indiranagar
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FareSplitSheet(split: split, areaByRiderId: const {"me": "Koramangala", "them": "Indiranagar"}),
        ),
      ),
    );

    // Percentages are visible before any fare is typed; rupees are not.
    expect(find.text("You · Koramangala"), findsOneWidget);
    expect(find.text("Ravi · Indiranagar"), findsOneWidget);
    expect(find.textContaining("₹"), findsNWidgets(1)); // only the input's prefix

    await tester.enterText(find.byType(TextField), "1000");
    await tester.pump();

    final amounts = split.amountsFor(1000);
    expect(amounts.fold<int>(0, (a, b) => a + b), 1000);
    expect(find.text("₹${amounts[0]}"), findsOneWidget);
    expect(find.text("₹${amounts[1]}"), findsOneWidget);
    expect(find.text("Just a suggestion"), findsOneWidget);
    expect(find.textContaining("never collects, holds or asks for money"), findsOneWidget);
  });
}
