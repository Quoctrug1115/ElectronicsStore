import 'dart:convert';

import 'package:http/http.dart' as http;

import 'token_storage.dart';

/// Lỗi nghiệp vụ / HTTP trả về từ backend, message đã là tiếng Việt.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Hàm dùng chung cho mọi service: header, giải mã body, đổi lỗi HTTP thành [ApiException].
class ApiClient {
  ApiClient._();

  /// Header kèm JWT. [json] = true khi gửi body JSON (không dùng cho multipart).
  static Future<Map<String, String>> authHeaders({bool json = false}) async {
    final token = await TokenStorage.getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic decodeBody(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    if (text.trim().isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  /// Trả body đã giải mã nếu 2xx, ngược lại ném [ApiException].
  static dynamic unwrap(http.Response response) {
    final data = decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) return data;
    throw toException(status, data);
  }

  static ApiException toException(int status, dynamic data) {
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
