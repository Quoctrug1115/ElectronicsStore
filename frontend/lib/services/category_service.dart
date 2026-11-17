import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/token_storage.dart';
import '../models/category_models.dart';
import '../services/auth_service.dart';

class CategoryService {
  CategoryService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<CategoryResponse>> getCategories({bool? isActive}) async {
    final query = <String, String>{};
    if (isActive != null) query['isActive'] = isActive.toString();

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.categories}')
        .replace(queryParameters: query);

    final response = await _client
        .get(uri, headers: await _authHeaders())
        .timeout(ApiConfig.timeout);

    final data = _decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return (data as List<dynamic>)
          .map((e) => CategoryResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _toApiException(status, data);
  }

  Future<CategoryResponse> getCategoryById(int id) async {
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.categories}/$id'),
          headers: await _authHeaders(),
        )
        .timeout(ApiConfig.timeout);

    final data = _decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return CategoryResponse.fromJson(data as Map<String, dynamic>);
    }
    throw _toApiException(status, data);
  }

  Future<CategoryResponse> createCategory(
    CategoryRequest request, {
    File? imageFile,
  }) async {
    final requestMulti = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.categories}'),
    )
      ..headers.addAll(await _authHeaders())
      ..fields.addAll(request.toFormFields());

    if (imageFile != null) {
      requestMulti.files.add(
        http.MultipartFile(
          'ImageFile',
          imageFile.readAsBytes().asStream(),
          imageFile.lengthSync(),
          filename: imageFile.path.split(Platform.pathSeparator).last,
        ),
      );
    }

    return _sendMultipart<CategoryResponse>(
      requestMulti,
      (json) => CategoryResponse.fromJson(json as Map<String, dynamic>),
      wrapperKey: 'data',
    );
  }

  Future<CategoryResponse> updateCategory(
    int id,
    CategoryRequest request, {
    File? imageFile,
  }) async {
    final requestMulti = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.categories}/$id'),
    )
      ..headers.addAll(await _authHeaders())
      ..fields.addAll(request.toFormFields());

    if (imageFile != null) {
      requestMulti.files.add(
        http.MultipartFile(
          'ImageFile',
          imageFile.readAsBytes().asStream(),
          imageFile.lengthSync(),
          filename: imageFile.path.split(Platform.pathSeparator).last,
        ),
      );
    }

    return _sendMultipart<CategoryResponse>(
      requestMulti,
      (json) => CategoryResponse.fromJson(json as Map<String, dynamic>),
      wrapperKey: 'data',
    );
  }

  Future<void> deleteCategory(int id) async {
    final response = await _client
        .delete(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.categories}/$id'),
          headers: await _authHeaders(),
        )
        .timeout(ApiConfig.timeout);

    final data = _decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) return;
    throw _toApiException(status, data);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await TokenStorage.getToken();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
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

  Future<T> _sendMultipart<T>(
    http.MultipartRequest request,
    T Function(dynamic) itemFromJson, {
    String? wrapperKey,
  }) async {
    final streamedResponse = await request.send().timeout(ApiConfig.timeout);
    final response = await http.Response.fromStream(streamedResponse);

    final data = _decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final json = wrapperKey == null || data is! Map
          ? data
          : data[wrapperKey];
      return itemFromJson(json);
    }
    throw _toApiException(status, data);
  }
}
