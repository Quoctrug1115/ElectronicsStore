import 'dart:convert';

class JwtHelper {
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = _decodeBase64Url(parts[1]);
      return jsonDecode(payload) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  static List<String> getRoles(String token) {
    final payload = decodePayload(token);
    if (payload == null) return [];
    const roleClaim =
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';
    final roles = payload[roleClaim] ?? payload['role'];
    if (roles == null) return [];
    if (roles is List) return roles.cast<String>();
    return [roles.toString()];
  }

  static String _decodeBase64Url(String str) {
    var s = str.replaceAll('-', '+').replaceAll('_', '/');
    while (s.length % 4 != 0) {
      s += '=';
    }
    return utf8.decode(base64Url.decode(s));
  }
}
