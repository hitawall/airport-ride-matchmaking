import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/app_theme.dart";
import "package:mobile/core/auth_controller.dart";
import "package:mobile/features/chat/chat_screen.dart";
import "support/memory_storage.dart";

class _Api extends ApiClient {
  _Api(this.messages);

  final List<Map<String, dynamic>> messages;

  @override
  Future<dynamic> get(String path) async {
    if (path == "/api/matches/m1") {
      return {
        "id": "m1",
        "status": "mutual",
        "userAId": "me",
        "userBId": "them",
        "counterpartDisplayName": "Ravi",
        "airportCode": "BLR",
        "terminal": "T1",
        "myTrolleyBags": 1,
        "counterpartTrolleyBags": 2,
      };
    }
    if (path.startsWith("/api/matches/m1/messages")) return {"messages": messages, "matchStatus": "mutual"};
    throw ApiException(404, "Not found");
  }
}

Future<void> _open(WidgetTester tester, List<Map<String, dynamic>> messages) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_Api(messages)),
        secureStorageProvider.overrideWithValue(MemoryStorage()),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const ChatScreen(matchId: "m1")),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets("a new chat suggests a landmark and can fill in a suggestion", (tester) async {
    await _open(tester, const []);
    expect(find.text("Suggest a spot"), findsOneWidget);
    expect(find.textContaining("windmills"), findsOneWidget);

    await tester.ensureVisible(find.text("Suggest a spot"));
    await tester.pump();
    await tester.tap(find.text("Suggest a spot"));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, contains("Shall we meet near a landmark"));
    expect(field.controller!.text, endsWith("wearing "));
  });

  testWidgets("the tip goes away once the conversation has started", (tester) async {
    await _open(tester, [
      {"id": "x1", "matchId": "m1", "senderId": "them", "body": "Hi!", "createdAt": "2026-12-01T10:00:00.000Z"},
    ]);
    expect(find.text("Suggest a spot"), findsNothing);
    expect(find.text("Hi!"), findsOneWidget);
  });
}
