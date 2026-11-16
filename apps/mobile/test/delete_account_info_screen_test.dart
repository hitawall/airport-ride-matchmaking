import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/features/legal/delete_account_info_screen.dart";

void main() {
  testWidgets("explains how to delete an account without being signed in", (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const DeleteAccountInfoScreen()),
      ),
    );
    await tester.pump();

    expect(find.text("Delete your account and data"), findsOneWidget);
    expect(find.text("What is deleted"), findsOneWidget);
    expect(find.text("Sign in to continue"), findsOneWidget);
  });
}
