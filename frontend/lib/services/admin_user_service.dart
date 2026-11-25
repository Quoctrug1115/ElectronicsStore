import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/admin_user_models.dart';

class AdminUserService {
  AdminUserService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PagedAdminUsers> getUsers({
    int pageIndex = 1,
    int pageSize = 10,
    String? search,
    String? role,
  }) async {
    final query = <String, String>{
      'pageIndex': '$pageIndex',
      'pageSize': '$pageSize',
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (role != null && role.isNotEmpty) 'role': role,
    };
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.adminUsers}')
              .replace(queryParameters: query),
          headers: await ApiClient.authHeaders(),
        )
        .timeout(ApiConfig.timeout);
    return PagedAdminUsers.fromJson(
      ApiClient.unwrap(response) as Map<String, dynamic>,
    );
  }

  Future<AdminUserDetail> getUserDetail(int id) async {
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.adminUsers}/$id'),
          headers: await ApiClient.authHeaders(),
        )
        .timeout(ApiConfig.timeout);
    return AdminUserDetail.fromJson(
      ApiClient.unwrap(response) as Map<String, dynamic>,
    );
  }

  /// Khóa / mở khóa; trả thông báo của server.
  Future<String> toggleLock(int id) async {
    final response = await _client
        .put(
          Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.adminUsers}/$id/toggle-lock',
          ),
          headers: await ApiClient.authHeaders(),
        )
        .timeout(ApiConfig.timeout);
    return _message(ApiClient.unwrap(response), 'Đã cập nhật tài khoản.');
  }

  /// [role] là `Member` hoặc `Admin`.
  Future<String> changeRole(int id, String role) async {
    final response = await _client
        .put(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.adminUsers}/$id/role'),
          headers: await ApiClient.authHeaders(json: true),
          body: jsonEncode({'role': role}),
        )
        .timeout(ApiConfig.timeout);
    return _message(ApiClient.unwrap(response), 'Đã đổi quyền.');
  }

  String _message(dynamic data, String fallback) =>
      data is Map && data['message'] is String
      ? data['message'] as String
      : fallback;
}
