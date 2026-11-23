import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'auth_service.dart';

/// Đăng nhập Facebook qua Facebook SDK, trả về access token.
class FacebookAuthService {
  /// Trả về access token, hoặc null nếu người dùng hủy.
  Future<String?> getAccessToken() async {
    if (kIsWeb) {
      throw const ApiException(
        'Đăng nhập Facebook chưa hỗ trợ trên trình duyệt. '
        'Hãy chạy app trên Android emulator hoặc máy thật.',
      );
    }
    try {
      final result = await FacebookAuth.instance.login(
        permissions: const ['public_profile', 'email'],
      );
      switch (result.status) {
        case LoginStatus.success:
          return result.accessToken?.tokenString;
        case LoginStatus.cancelled:
          return null;
        default:
          throw ApiException(
            'Đăng nhập Facebook thất bại: ${result.message ?? result.status.name}',
          );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Không thể đăng nhập Facebook: $e');
    }
  }
}
