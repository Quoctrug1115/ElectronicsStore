import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

/// Lấy idToken từ Google. Web client ID dùng làm serverClientId để backend xác thực token.
class GoogleAuthService {
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '1289611861-tdvrb3m403nt6bb03d0iivk5l12ckllj.apps.googleusercontent.com',
  );

  static bool _initialized = false;

  /// Trả về idToken, hoặc null nếu người dùng hủy.
  Future<String?> getIdToken() async {
    if (kIsWeb) {
      throw const ApiException(
        'Đăng nhập Google chưa hỗ trợ trên trình duyệt. '
        'Hãy chạy app trên Android emulator hoặc máy thật.',
      );
    }
    final signIn = GoogleSignIn.instance;
    try {
      if (!_initialized) {
        await signIn.initialize(serverClientId: webClientId);
        _initialized = true;
      }
      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const ApiException('Không lấy được token từ Google.');
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw ApiException('Đăng nhập Google thất bại (${e.code.name}).');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Không thể đăng nhập Google: $e');
    }
  }

  Future<void> signOut() async {
    if (_initialized) await GoogleSignIn.instance.signOut();
  }
}
