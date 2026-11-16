import "package:flutter_secure_storage/flutter_secure_storage.dart";

class SecureStorage {
  const SecureStorage();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = "auth_token";
  static const _userIdKey = "auth_user_id";

  Future<void> saveSession(String token, String userId) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<(String, String)?> readSession() async {
    final token = await _storage.read(key: _tokenKey);
    final userId = await _storage.read(key: _userIdKey);
    if (token == null || userId == null) return null;
    return (token, userId);
  }

  /// Small non-secret values kept on this device (e.g. matches already seen).
  Future<String?> readString(String key) => _storage.read(key: key);

  Future<void> writeString(String key, String value) => _storage.write(key: key, value: value);

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
  }
}
