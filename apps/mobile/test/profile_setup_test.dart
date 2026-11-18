import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/features/profile/profile_setup_screen.dart";
import "support/memory_storage.dart";

class _Api extends ApiClient {
  _Api({this.existing});

  final Map<String, dynamic>? existing;

  @override
  Future<dynamic> get(String path) async {
    if (path == "/api/profile/me") {
      if (existing == null) throw ApiException(404, "Not found");
      return existing;
    }
    throw ApiException(404, "Not found");
  }
}

Future<String Function()> _open(WidgetTester tester, {Map<String, dynamic>? existing, String? pendingPhone}) async {
  tester.view.physicalSize = const Size(412, 2000) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  var location = "/profile-setup";
  final router = GoRouter(
    initialLocation: "/profile-setup",
    routes: [
      GoRoute(path: "/profile-setup", builder: (context, state) => const ProfileSetupScreen()),
      GoRoute(path: "/email", builder: (context, state) => const Text("email screen")),
    ],
  );
  router.routerDelegate.addListener(() => location = router.routerDelegate.currentConfiguration.uri.path);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_Api(existing: existing)),
        secureStorageProvider.overrideWithValue(MemoryStorage()),
        pendingSignupPhoneNumberProvider.overrideWith((ref) => pendingPhone),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return () => location;
}

void main() {
  testWidgets("a new profile shows the phone number to fix, and a way to start over with another email", (tester) async {
    final location = await _open(tester, pendingPhone: "+919876543210");
    expect(find.text("Set up your profile"), findsOneWidget);
    expect(find.widgetWithText(TextField, "Mobile number"), findsOneWidget);
    expect(find.text("9876543210"), findsOneWidget, reason: "prefilled from the sign-up screen");

    await tester.ensureVisible(find.text("Used the wrong email? Start over"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Used the wrong email? Start over"));
    await tester.pumpAndSettle();
    expect(location(), "/email");
  });

  testWidgets("an existing profile can edit the number but has no start-over", (tester) async {
    await _open(tester, existing: {
      "displayName": "Asha",
      "gender": "female",
      "genderPreference": "any",
      "phoneNumber": "+919876543210",
    });
    expect(find.text("Edit profile"), findsOneWidget);
    expect(find.widgetWithText(TextField, "Mobile number"), findsOneWidget);
    expect(find.text("Used the wrong email? Start over"), findsNothing);
  });

  testWidgets("gender is required, offers only Male, Female and Other, and says why", (tester) async {
    await _open(tester, pendingPhone: "+919876543210");
    expect(find.widgetWithText(ChoiceChip, "Male"), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, "Female"), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, "Other"), findsOneWidget);
    expect(find.text("Prefer not to say"), findsNothing);
    expect(find.textContaining("matched only with travelers of your own gender"), findsOneWidget);
    expect(tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).where((c) => c.selected), isEmpty);

    await tester.enterText(find.widgetWithText(TextField, "Display name"), "Asha");
    await tester.tap(find.text("Continue"));
    await tester.pumpAndSettle();
    expect(find.text("Choose your gender to continue"), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, "Other"));
    await tester.pumpAndSettle();
    expect(find.text("Choose your gender to continue"), findsNothing);
  });

  testWidgets("an older profile that said prefer not to say is asked to choose", (tester) async {
    await _open(tester, existing: {
      "displayName": "Asha",
      "gender": "prefer_not_to_say",
      "genderPreference": "any",
      "phoneNumber": "+919876543210",
    });
    expect(tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).where((c) => c.selected), isEmpty);
  });
}
