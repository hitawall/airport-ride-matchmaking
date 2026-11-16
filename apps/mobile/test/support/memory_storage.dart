import "package:mobile/core/secure_storage.dart";

/// Stands in for the device's secure storage in tests (the real one needs a
/// platform plugin). Starts signed out and remembers what is written.
class MemoryStorage extends SecureStorage {
  final _values = <String, String>{};

  @override
  Future<(String, String)?> readSession() async => null;

  @override
  Future<void> saveSession(String token, String userId) async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<String?> readString(String key) async => _values[key];

  @override
  Future<void> writeString(String key, String value) async => _values[key] = value;
}
