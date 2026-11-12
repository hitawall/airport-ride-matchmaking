import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mobile/main.dart";

void main() {
  testWidgets("renders the placeholder home screen", (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AirportRideMatchmakingApp()),
    );
    expect(find.text("Airport Ride Matchmaking"), findsOneWidget);
  });
}
