import "dart:convert";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/data/airports.dart";
import "package:mobile/data/models.dart";

void main() {
  group("models read what the API sends", () {
    test("candidate accepts ratings as numbers or strings", () {
      Candidate parse(Object? avg, Object? count) => Candidate.fromJson({
        "id": "r1",
        "user_id": "u1",
        "display_name": "Asha",
        "gender": "female",
        "flight_arrival_at": "2026-12-01T10:00:00.000Z",
        "destination_locality_label": "Indiranagar",
        "avg_rating": avg,
        "rating_count": count,
      });
      expect(parse("4.50", "2").avgRating, 4.5);
      expect(parse("4.50", "2").ratingCount, 2);
      expect(parse(3, 7).avgRating, 3.0);
      expect(parse(null, null).avgRating, isNull);
      expect(parse(null, null).ratingCount, 0);
    });

    test("match summary tolerates a missing or bad update time", () {
      MatchSummary parse(Object? updated) => MatchSummary.fromJson({
        "id": "m1",
        "status": "mutual",
        "counterpart_display_name": "Ravi",
        "updated_at": updated,
      });
      expect(parse("2026-12-01T10:00:00.000Z").updatedAt, isNotNull);
      expect(parse(null).updatedAt, isNull);
      expect(parse("not a date").updatedAt, isNull);
    });

    test("chat message reads its timestamp", () {
      final message = ChatMessage.fromJson({
        "id": "c1",
        "matchId": "m1",
        "senderId": "u1",
        "body": "hi",
        "createdAt": "2026-12-01T10:00:00.000Z",
      });
      expect(message.createdAt.toUtc().hour, 10);
    });

    test("airport catalogue works with or without airport coordinates", () {
      Airport parse(Map<String, dynamic> extra) => Airport.fromJson({
        "code": "BLR",
        "name": "Kempegowda",
        "city": "Bengaluru",
        "terminals": [
          {"code": "T1", "name": "Terminal 1"},
        ],
        "localities": [
          {"label": "Indiranagar", "lat": 12.97, "lng": 77.64},
        ],
        ...extra,
      });
      expect(parse({}).lat, isNull);
      expect(parse({"lat": 13.19, "lng": 77.7}).lat, 13.19);
      expect(parse({}).localities.single.label, "Indiranagar");
    });
  });

  group("ApiClient", () {
    Future<T> withReply<T>(http.Response Function(http.Request) reply, Future<T> Function() body) =>
        http.runWithClient(body, () => MockClient((request) async => reply(request)));

    test("sends the sign-in token and returns decoded JSON", () async {
      late http.Request seen;
      final result = await withReply((request) {
        seen = request;
        return http.Response(jsonEncode({"ok": true}), 200);
      }, () => ApiClient(token: "abc").get("/api/health"));
      expect(result, {"ok": true});
      expect(seen.headers["Authorization"], "Bearer abc");
      expect(seen.url.path, "/api/health");
    });

    test("uses the server's error text", () async {
      expect(
        withReply((_) => http.Response(jsonEncode({"error": "Too many codes"}), 429), () => ApiClient().get("/x")),
        throwsA(isA<ApiException>().having((e) => e.message, "message", "Too many codes").having((e) => e.statusCode, "status", 429)),
      );
    });

    test("falls back to a generic message when the error has no text", () async {
      expect(
        withReply((_) => http.Response("", 500), () => ApiClient().get("/x")),
        throwsA(isA<ApiException>().having((e) => e.message, "message", "Request failed (500)")),
      );
    });

    test("an empty success body is null, and post sends JSON", () async {
      late http.Request seen;
      final result = await withReply((request) {
        seen = request;
        return http.Response("", 204);
      }, () => ApiClient().post("/x", {"a": 1}));
      expect(result, isNull);
      expect(jsonDecode(seen.body), {"a": 1});
      expect(seen.headers["Content-Type"], contains("application/json"));
    });
  });
}
