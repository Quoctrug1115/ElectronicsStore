import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/auth_models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

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

  Future<String?> getToken() async {
    // This will be implemented using TokenStorage
    return null; // Placeholder - actual implementation in TokenStorage
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

    final data = _decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) return data;
    throw _toApiException(status, data);
  }

  dynamic _decodeBody(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    if (text.trim().isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  ApiException _toApiException(int status, dynamic data) {
    if (data is Map) {
      if (data['message'] is String) {
        return ApiException(data['message'] as String, statusCode: status);
      }
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final messages = errors.values
            .expand((v) => v is List ? v : [v])
            .map((v) => v.toString())
            .join('\n');
        return ApiException(messages, statusCode: status);
      }
    }

    if (status == 401) {
      return const ApiException(
        'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.',
        statusCode: 401,
      );
    }
    if (status == 403) {
      return const ApiException(
        'Bạn không có quyền thực hiện thao tác này.',
        statusCode: 403,
      );
    }
    return ApiException('Đã xảy ra lỗi (mã $status).', statusCode: status);
  }
}
