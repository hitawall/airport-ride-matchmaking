import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/core/ui/required_label.dart";
import "package:mobile/features/onboarding/email_entry_screen.dart";
import "package:mobile/features/profile/profile_setup_screen.dart";
import "support/memory_storage.dart";

class _Api extends ApiClient {
  @override
  Future<dynamic> get(String path) async => throw ApiException(404, "Not found");
}

Future<void> _open(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(412, 2000) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_Api()),
        secureStorageProvider.overrideWithValue(MemoryStorage()),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _starIn(Finder label) => find.descendant(of: find.ancestor(of: label, matching: find.byType(RequiredLabel)), matching: find.text(" *"));

void main() {
  testWidgets("the label shows a red asterisk", (tester) async {
    await _open(tester, const Scaffold(body: Center(child: RequiredLabel("Name"))));
    final star = tester.widget<Text>(find.text(" *"));
    expect(star.style?.color, AppTheme.light().colorScheme.error);
  });

  testWidgets("sign-up marks email and mobile number as required", (tester) async {
    await _open(tester, const EmailEntryScreen());
    expect(_starIn(find.text("Email address")), findsOneWidget);
    expect(_starIn(find.text("Mobile number")), findsOneWidget);
  });

  testWidgets("profile setup marks name, gender and mobile number, but not the bio", (tester) async {
    await _open(tester, const ProfileSetupScreen());
    expect(_starIn(find.text("Display name")), findsOneWidget);
    expect(_starIn(find.text("I identify as")), findsOneWidget);
    expect(_starIn(find.text("Mobile number")), findsOneWidget);
    expect(find.text("Bio (optional)"), findsOneWidget);
  });
}
