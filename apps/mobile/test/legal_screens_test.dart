import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/app_config.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/features/legal/legal_content.dart";
import "package:mobile/features/legal/legal_document_screen.dart";
import "package:mobile/features/support/support_sheet.dart";

void main() {
  testWidgets("privacy policy shows the draft notice and unset placeholders", (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: LegalDocumentScreen(document: buildPrivacyPolicy())));

    expect(find.text("Privacy policy"), findsWidgets);
    expect(find.text("What we collect"), findsOneWidget);
    // Nothing is configured in tests, so the owner-supplied values show as
    // obvious placeholders and the draft notice is visible.
    expect(AppConfig.legalReviewed, isFalse);
    expect(find.text("Draft"), findsOneWidget);
    expect(find.textContaining("[operator name not set]", findRichText: true), findsWidgets);
  });

  test("privacy policy covers every data type the app collects", () {
    final text = buildPrivacyPolicy().sections.expand((s) => s.paragraphs).join(" ").toLowerCase();
    for (final word in ["email", "photo", "mobile number", "messages", "flight", "delete your account"]) {
      expect(text, contains(word));
    }
  });

  test("terms say the app does not handle payments", () {
    final text = buildTerms().sections.expand((s) => s.paragraphs).join(" ").toLowerCase();
    expect(text, contains("never handle payments"));
    expect(text, contains("18"));
  });

  testWidgets("support sheet explains when no address is configured", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => showSupportSheet(context), child: const Text("open")),
          ),
        ),
      ),
    );
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    expect(find.text("Contact support"), findsOneWidget);
    expect(find.textContaining("isn't set up yet"), findsOneWidget);
    expect(find.text("Copy email address"), findsNothing);
  });
}
