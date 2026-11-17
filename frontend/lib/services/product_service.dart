import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/token_storage.dart';
import '../models/product_models.dart';
import '../services/auth_service.dart';

class ProductService {
  ProductService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PagedResult<ProductListItem>> getProducts({
    int pageIndex = 1,
    int pageSize = 10,
    String? search,
    int? categoryId,
    int? brandId,
    String sortBy = 'newest',
  }) async {
    final query = <String, String>{
      'pageIndex': pageIndex.toString(),
      'pageSize': pageSize.toString(),
      'sortBy': sortBy,
    };
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (categoryId != null) query['categoryId'] = categoryId.toString();
    if (brandId != null) query['brandId'] = brandId.toString();

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.products}')
        .replace(queryParameters: query);

    final response = await _client
        .get(uri, headers: await _authHeaders())
        .timeout(ApiConfig.timeout);

    final data = _decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return PagedResult<ProductListItem>.fromJson(
        data as Map<String, dynamic>,
        ProductListItem.fromJson,
      );
    }
    throw _toApiException(status, data);
  }

  Future<ProductDetail> getProductById(int id) async {
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.products}/$id'),
          headers: await _authHeaders(),
        )
        .timeout(ApiConfig.timeout);

    final data = _decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return ProductDetail.fromJson(data as Map<String, dynamic>);
    }
    throw _toApiException(status, data);
  }

  Future<ProductDetail> createProduct(
    ProductRequest request, {
    required List<File> imageFiles,
  }) async {
    final response = await _postMultipart(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.products}'),
      request.toFormFields(),
      imageFiles.map((f) => _toMultipartFile(f, 'ImageFiles')).toList(),
    );
    final data = response.data;
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final productId = (data as Map)['productId'] as num?;
      if (productId != null) return getProductById(productId.toInt());
      return ProductDetail.fromJson(data as Map<String, dynamic>);
    }
    throw _toApiException(status, data);
  }

  Future<ProductDetail> updateProduct(
    int id,
    ProductRequest request, {
    required List<File> imageFiles,
  }) async {
    final response = await _postMultipart(
      'PUT',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.products}/$id'),
      request.toFormFields(),
      imageFiles.map((f) => _toMultipartFile(f, 'ImageFiles')).toList(),
    );
    final data = response.data;
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return getProductById(id);
    }
    throw _toApiException(status, data);
  }

  Future<void> deleteProduct(int id) async {
    final response = await _client
        .delete(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.products}/$id'),
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

  Future<({dynamic data, int statusCode})> _postMultipart(
    String method,
    Uri uri,
    Map<String, String> fields,
    List<http.MultipartFile> files,
  ) async {
    final request = http.MultipartRequest(method, uri)
      ..headers.addAll(await _authHeaders())
      ..fields.addAll(fields)
      ..files.addAll(files);

    final streamedResponse = await request.send().timeout(ApiConfig.timeout);
    final response = await http.Response.fromStream(streamedResponse);
    return (data: _decodeBody(response), statusCode: response.statusCode);
  }

  http.MultipartFile _toMultipartFile(File file, String fieldName) =>
      http.MultipartFile(
        fieldName,
        file.readAsBytes().asStream(),
        file.lengthSync(),
        filename: file.path.split(Platform.pathSeparator).last,
      );
}
