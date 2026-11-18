import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/features/onboarding/email_entry_screen.dart";
import "support/memory_storage.dart";

const _taken = "That mobile number is already used by another account. Use a different number, or sign in with the email you first used.";

class _Api extends ApiClient {
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    bodies.add(body ?? {});
    throw ApiException(409, _taken);
  }
}

void main() {
  testWidgets("a mobile number another account has is refused on the sign-up screen, under the number", (tester) async {
    tester.view.physicalSize = const Size(412, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final api = _Api();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          secureStorageProvider.overrideWithValue(MemoryStorage()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const EmailEntryScreen()),
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, "Email address"), "new@example.com");
    await tester.enterText(find.widgetWithText(TextField, "Mobile number"), "9876543210");
    await tester.tap(find.text("Send code"));
    await tester.pumpAndSettle();

    // The number goes with the request, so the server can refuse it up front.
    expect(api.bodies.single["phoneNumber"], "+919876543210");
    // The error is about the number, so it appears under the number, not the email.
    expect(find.text(_taken), findsOneWidget);
    final emailField = tester.widget<TextField>(find.widgetWithText(TextField, "Email address"));
    expect(emailField.decoration!.errorText, isNull);
  });
}
