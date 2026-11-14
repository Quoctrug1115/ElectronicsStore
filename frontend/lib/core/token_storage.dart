import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyRoles = 'user_roles';

  static Future<void> saveToken(String token) async =>
      _storage.write(key: _keyToken, value: token);

  static Future<String?> getToken() => _storage.read(key: _keyToken);

  static Future<void> saveRefreshToken(String token) async =>
      _storage.write(key: _keyRefresh, value: token);

  static Future<String?> getRefreshToken() => _storage.read(key: _keyRefresh);

  static Future<void> saveRoles(List<String> roles) async =>
      _storage.write(key: _keyRoles, value: roles.join(','));

  static Future<List<String>> getRoles() async {
    final v = await _storage.read(key: _keyRoles);
    if (v == null || v.isEmpty) return [];
    return v.split(',');
  }

  static Future<void> clear() async => _storage.deleteAll();
}
