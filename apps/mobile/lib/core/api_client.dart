import "dart:convert";
import "package:http/http.dart" as http;
import "package:http_parser/http_parser.dart" show MediaType;

const apiBaseUrl = String.fromEnvironment(
  "API_BASE_URL",
  defaultValue: "http://localhost:3000",
);

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({this.token});

  final String? token;

  Map<String, String> get _headers => {
    "Content-Type": "application/json",
    if (token != null) "Authorization": "Bearer $token",
  };

  Uri _uri(String path) => Uri.parse("$apiBaseUrl$path");

  Future<dynamic> get(String path) => _send("GET", path);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send("POST", path, body);

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _send("PUT", path, body);

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) =>
      _send("PATCH", path, body);

  Future<dynamic> delete(String path) => _send("DELETE", path);

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = _uri(path);
    final encodedBody = body == null ? null : jsonEncode(body);
    final http.Response response;
    switch (method) {
      case "GET":
        response = await http.get(uri, headers: _headers);
      case "POST":
        response = await http.post(uri, headers: _headers, body: encodedBody);
      case "PUT":
        response = await http.put(uri, headers: _headers, body: encodedBody);
      case "PATCH":
        response = await http.patch(uri, headers: _headers, body: encodedBody);
      case "DELETE":
        response = await http.delete(uri, headers: _headers);
      default:
        throw ApiException(0, "Unsupported method $method");
    }

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = (decoded is Map && decoded["error"] is String)
          ? decoded["error"] as String
          : "Request failed (${response.statusCode})";
      throw ApiException(response.statusCode, message);
    }
    return decoded;
  }

  /// Uploads a profile photo as multipart/form-data; [bytes] is the raw image data.
  Future<String> uploadProfilePhoto(List<int> bytes, String filename, String contentType) async {
    final request = http.MultipartRequest("POST", _uri("/api/profile/photo"))
      ..headers.addAll({if (token != null) "Authorization": "Bearer $token"})
      ..files.add(
        http.MultipartFile.fromBytes(
          "photo",
          bytes,
          filename: filename,
          contentType: _parseContentType(contentType),
        ),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, decoded["error"] as String? ?? "Upload failed");
    }
    return decoded["photoUrl"] as String;
  }
}

MediaType _parseContentType(String contentType) => MediaType.parse(contentType);
