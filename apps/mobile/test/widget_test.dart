import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mobile/main.dart";

void main() {
  testWidgets("renders the legal interstitial on first launch", (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AirportRideMatchmakingApp()),
    );
    await tester.pump();
    expect(find.text("Before you start"), findsOneWidget);
    expect(find.text("I understand, continue"), findsOneWidget);
  });
}
