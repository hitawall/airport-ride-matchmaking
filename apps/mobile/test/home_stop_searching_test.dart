import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/features/onboarding/home_screen.dart";
import "support/memory_storage.dart";

/// A rider who is searching; remembers what was patched.
class _SearchingApi extends ApiClient {
  String status = "open";
  final patches = <String>[];

  @override
  Future<dynamic> get(String path) async {
    if (path == "/api/profile/me") return {"displayName": "Asha"};
    if (path == "/api/ride-requests/mine") {
      return {
        "id": "r1",
        "status": status,
        "flightArrivalAt": "2026-12-01T10:00:00.000Z",
        "destinationLocalityLabel": "Indiranagar",
        "airportCode": "BLR",
        "terminal": "T1",
      };
    }
    throw ApiException(404, "Not found");
  }

  @override
  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    patches.add("$path ${body?["status"]}");
    status = "cancelled";
    return {};
  }
}

void main() {
  testWidgets("Stop searching on the home screen asks first, then cancels the search", (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final api = _SearchingApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          secureStorageProvider.overrideWithValue(MemoryStorage()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Stop searching"));
    await tester.pumpAndSettle();
    expect(find.text("Stop searching?"), findsOneWidget);

    // Keeping the search does nothing.
    await tester.tap(find.text("Keep searching"));
    await tester.pumpAndSettle();
    expect(api.patches, isEmpty);

    await tester.tap(find.text("Stop searching"));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text("Stop searching")));
    await tester.pumpAndSettle();
    expect(api.patches, ["/api/ride-requests/r1 cancelled"]);
    // The trip is gone, so the button goes with it and the rider can search again.
    expect(find.text("Find a ride partner"), findsOneWidget);
  });
}
