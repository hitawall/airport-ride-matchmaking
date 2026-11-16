import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/features/onboarding/home_screen.dart";

/// A signed-in rider with a profile and no trip yet.
class _NewRiderApi extends ApiClient {
  @override
  Future<dynamic> get(String path) async {
    if (path == "/api/profile/me") return {"displayName": "Asha"};
    throw ApiException(404, "No ride request found");
  }
}

void main() {
  testWidgets("Find a ride partner is visible without scrolling on a small phone", (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(_NewRiderApi())],
        child: MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.text("Find a ride partner");
    expect(button, findsOneWidget);
    // Fully inside the first screenful (640 logical px tall), not pinned out of sight.
    expect(tester.getBottomLeft(button).dy, lessThan(640));
    // And above the "My matches" tile, so it is the first thing a new rider sees.
    expect(tester.getTopLeft(button).dy, lessThan(tester.getTopLeft(find.text("My matches")).dy));
  });
}
