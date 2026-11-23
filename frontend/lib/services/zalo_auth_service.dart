import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:zalo_flutter/zalo_flutter.dart';

import 'auth_service.dart';

/// Đăng nhập Zalo qua Zalo SDK (mở app Zalo hoặc webview), trả về access token.
class ZaloAuthService {
  /// Trả về access token, hoặc null nếu người dùng hủy.
  Future<String?> getAccessToken() async {
    if (kIsWeb) {
      throw const ApiException(
        'Đăng nhập Zalo chưa hỗ trợ trên trình duyệt. '
        'Hãy chạy app trên Android emulator hoặc máy thật.',
      );
    }
    try {
      final result = await ZaloFlutter.login();
      if (result == null) return null;
      final token = result['access_token'] ?? result['accessToken'];
      if (token is String && token.isNotEmpty) return token;

      final message = result['error_description'] ?? result['message'];
      if (message is String && message.isNotEmpty) {
        throw ApiException('Đăng nhập Zalo thất bại: $message');
      }
      return null; // thường là người dùng hủy
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Không thể đăng nhập Zalo: $e');
    }
  }
}
