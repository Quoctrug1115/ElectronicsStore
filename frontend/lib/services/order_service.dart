import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/token_storage.dart';
import '../models/order_models.dart';

class OrderService {
  OrderService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<OrderResponse> createOrder(CreateOrderRequest request) async {
    final headers = await _authHeaders();

    // 1. Làm sạch giỏ hàng tạm trên server (nếu có) để tránh trùng số lượng
    await _client
        .delete(
          Uri.parse('${ApiConfig.baseUrl}/api/cart'),
          headers: headers,
        )
        .timeout(ApiConfig.timeout);

    // 2. Đồng bộ từng sản phẩm từ giỏ hàng Flutter lên bảng CartItems của Backend
    for (final item in request.items) {
      if (item.variantId == null) {
        throw const ApiException(
          'Sản phẩm trong giỏ hàng thiếu thông tin phiên bản (VariantId).',
        );
      }

      final addRes = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/cart/items'),
            headers: headers,
            body: jsonEncode({
              'variantId': item.variantId,
              'quantity': item.quantity,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (addRes.statusCode < 200 || addRes.statusCode >= 300) {
        throw _toApiException(addRes.statusCode, _decodeBody(addRes));
      }
    }

    // 3. Gọi API Checkout tạo đơn hàng
    final response = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.orders}/checkout'),
          headers: headers,
          body: jsonEncode(request.toJson()),
        )
        .timeout(ApiConfig.timeout);

    final data = _decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final map = data as Map<String, dynamic>;
      final orderJson = (map['data'] is Map<String, dynamic>)
          ? map['data'] as Map<String, dynamic>
          : map;
      return OrderResponse.fromJson(orderJson);
    }
    throw _toApiException(status, data);
  }
  Future<PagedResultOrder> getOrders({
    int pageIndex = 1,
    int pageSize = 10,
    String? status,
  }) async {
    final query = <String, String>{
      'pageIndex': pageIndex.toString(),
      'pageSize': pageSize.toString(),
    };
    if (status != null && status.isNotEmpty) query['status'] = status;

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.orders}')
        .replace(queryParameters: query);

    final response = await _client
        .get(uri, headers: await _authHeaders())
        .timeout(ApiConfig.timeout);

    final data = _decodeBody(response);
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      return PagedResultOrder.fromJson(data as Map<String, dynamic>);
    }
    throw _toApiException(statusCode, data);
  }

  Future<OrderResponse> getOrderById(int id) async {
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.orders}/$id'),
          headers: await _authHeaders(),
        )
        .timeout(ApiConfig.timeout);

    final data = _decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return OrderResponse.fromJson(data as Map<String, dynamic>);
    }
    throw _toApiException(status, data);
  }

  Future<void> cancelOrder(int id) async {
    final response = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.orders}/$id/cancel'),
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
      'Content-Type': 'application/json',
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
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}