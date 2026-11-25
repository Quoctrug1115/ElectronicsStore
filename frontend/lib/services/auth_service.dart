import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/auth_models.dart';

// Giữ đường dẫn import cũ: các màn hình vẫn lấy ApiException từ đây.
export '../core/api_client.dart' show ApiException;

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthResponse> register(RegisterRequest request) async {
    final data = await _post(ApiConfig.register, request.toJson());
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final data = await _post(ApiConfig.login, request.toJson());
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResponse> loginWithGoogle(String idToken) async {
    final data = await _post(ApiConfig.googleLogin, {'idToken': idToken});
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResponse> loginWithZalo(String accessToken) async {
    final data = await _post(ApiConfig.zaloLogin, {'accessToken': accessToken});
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResponse> loginWithFacebook(String accessToken) async {
    final data = await _post(ApiConfig.facebookLogin, {
      'accessToken': accessToken,
    });
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Gửi OTP quên mật khẩu tới email.
  Future<String> forgotPassword(String email) => _postMessage(
    ApiConfig.forgotPassword,
    {'email': email},
    'Đã gửi mã OTP tới email của bạn.',
  );

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmNewPassword,
  }) => _postMessage(ApiConfig.resetPassword, {
    'email': email,
    'otp': otp,
    'newPassword': newPassword,
    'confirmNewPassword': confirmNewPassword,
  }, 'Đặt lại mật khẩu thành công.');

  Future<String> sendVerificationOtp(String email) => _postMessage(
    ApiConfig.sendVerificationOtp,
    {'email': email},
    'Đã gửi mã OTP tới email của bạn.',
  );

  Future<String> verifyEmail({required String email, required String otp}) =>
      _postMessage(ApiConfig.verifyEmail, {
        'email': email,
        'otp': otp,
      }, 'Xác thực email thành công.');

  Future<String> changePassword(
    ChangePasswordRequest request, {
    required String accessToken,
  }) async {
    final data = await _post(
      ApiConfig.changePassword,
      request.toJson(),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Đổi mật khẩu thành công.';
  }

  Future<String> _postMessage(
    String path,
    Map<String, dynamic> body,
    String fallback,
  ) async {
    final data = await _post(path, body);
    return data is Map && data['message'] is String
        ? data['message'] as String
        : fallback;
  }

  Future<dynamic> _post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...?headers,
            },
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);
    } on TimeoutException {
      throw const ApiException('Máy chủ phản hồi quá lâu, vui lòng thử lại.');
    } on http.ClientException {
      throw ApiException(
        'Không kết nối được máy chủ (${ApiConfig.baseUrl}). '
        'Kiểm tra backend đã chạy và địa chỉ API.',
      );
    }

    return ApiClient.unwrap(response);
  }
}
