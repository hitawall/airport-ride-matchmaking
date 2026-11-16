import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/core/secure_storage.dart";
import "package:mobile/features/install/install.dart";

class _MemoryStorage extends SecureStorage {
  final _values = <String, String>{};

  @override
  Future<String?> readString(String key) async => _values[key];

  @override
  Future<void> writeString(String key, String value) async => _values[key] = value;
}

Widget _app(InstallKind kind) => ProviderScope(
  overrides: [installKindProvider.overrideWithValue(kind), secureStorageProvider.overrideWithValue(_MemoryStorage())],
  child: MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: InstallBanner())),
);

void main() {
  test("manual steps differ for iPhone and Firefox", () {
    expect(installSteps(InstallKind.ios), contains("Share"));
    expect(installSteps(InstallKind.firefox), contains("menu"));
    expect(installSteps(InstallKind.none), isEmpty);
  });

  testWidgets("shows nothing where the app cannot be installed (or already is)", (tester) async {
    await tester.pumpWidget(_app(InstallKind.none));
    await tester.pumpAndSettle();
    expect(find.text("Get the app on your home screen"), findsNothing);
  });

  testWidgets("iPhone gets the Share steps and no install button", (tester) async {
    await tester.pumpWidget(_app(InstallKind.ios));
    await tester.pumpAndSettle();
    expect(find.text("Get the app on your home screen"), findsOneWidget);
    expect(find.textContaining("Add to Home Screen"), findsOneWidget);
    expect(find.text("Install"), findsNothing);
  });

  testWidgets("Chrome gets an Install button", (tester) async {
    await tester.pumpWidget(_app(InstallKind.prompt));
    await tester.pumpAndSettle();
    expect(find.text("Install"), findsOneWidget);
  });
}
