import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/data/airports.dart";
import "package:mobile/features/legal/delete_account_info_screen.dart";
import "package:mobile/features/legal/legal_content.dart";
import "package:mobile/features/legal/legal_document_screen.dart";
import "package:mobile/features/matching/match_list_screen.dart";
import "package:mobile/features/onboarding/email_entry_screen.dart";
import "package:mobile/features/onboarding/home_screen.dart";
import "package:mobile/features/onboarding/legal_interstitial_screen.dart";
import "package:mobile/features/ride_request/create_ride_request_screen.dart";
import "package:mobile/features/settings/settings_screen.dart";
import "support/memory_storage.dart";

/// A rider with a profile and no trip.
class _FakeApi extends ApiClient {
  @override
  Future<dynamic> get(String path) async {
    if (path == "/api/profile/me") return {"displayName": "Asha Raman", "gender": "female"};
    if (path == "/api/matches") return <dynamic>[];
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
      terminals: [Terminal(code: "T1", name: "Terminal 1"), Terminal(code: "T2", name: "Terminal 2")],
      localities: [Locality("Indiranagar", 12.9719, 77.6412), Locality("Koramangala", 12.9352, 77.6245)],
    ),
  ],
);

/// Every screen a rider reaches before and after signing in. Chat and the
/// camera scanner need live services and are covered by their own tests.
final _screens = <String, Widget Function()>{
  "welcome": () => const LegalInterstitialScreen(),
  "email entry": () => const EmailEntryScreen(),
  "home": () => const HomeScreen(),
  "create trip": () => const CreateRideRequestScreen(),
  "my matches": () => const MatchListScreen(),
  "settings": () => const SettingsScreen(),
  "privacy policy": () => LegalDocumentScreen(document: buildPrivacyPolicy()),
  "terms": () => LegalDocumentScreen(document: buildTerms()),
  "delete account help": () => const DeleteAccountInfoScreen(),
};

const _sizes = {
  "small phone": Size(360, 640),
  "large phone": Size(412, 915),
  "desktop": Size(1280, 800),
};

Future<void> _show(WidgetTester tester, Widget screen, Size size, {double textScale = 1}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApi()),
        secureStorageProvider.overrideWithValue(MemoryStorage()),
        airportCatalogProvider.overrideWith((ref) async => _catalog),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group("nothing overflows or throws", () {
    for (final screen in _screens.entries) {
      for (final size in _sizes.entries) {
        testWidgets("${screen.key} on a ${size.key}", (tester) async {
          await _show(tester, screen.value(), size.value);
          expect(tester.takeException(), isNull);
        });
      }
      testWidgets("${screen.key} with text enlarged to 150% on a small phone", (tester) async {
        await _show(tester, screen.value(), _sizes["small phone"]!, textScale: 1.5);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group("accessibility", () {
    for (final screen in _screens.entries) {
      testWidgets("${screen.key}: tap targets are big enough and labelled, text has enough contrast", (tester) async {
        final handle = tester.ensureSemantics();
        await _show(tester, screen.value(), _sizes["small phone"]!);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });
}
