import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/order_models.dart';

export '../core/api_client.dart' show ApiException;

class OrderService {
  OrderService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<OrderResponse> createOrder(CreateOrderRequest request) async {
    final headers = await ApiClient.authHeaders(json: true);

    // 1. Làm sạch giỏ hàng tạm trên server (nếu có) để tránh trùng số lượng
    await _client
        .delete(Uri.parse('${ApiConfig.baseUrl}/api/cart'), headers: headers)
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

      ApiClient.unwrap(addRes);
    }

    // 3. Gọi API Checkout tạo đơn hàng
    final response = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.orders}/checkout'),
          headers: headers,
          body: jsonEncode(request.toJson()),
        )
        .timeout(ApiConfig.timeout);

    final map = ApiClient.unwrap(response) as Map<String, dynamic>;
    final orderJson = map['data'] is Map<String, dynamic>
        ? map['data'] as Map<String, dynamic>
        : map;
    return OrderResponse.fromJson(orderJson);
  }

  /// Danh sách đơn. [admin] = true gọi `/api/admin/orders` (toàn bộ đơn), ngược lại chỉ đơn của mình.
  Future<PagedResultOrder> getOrders({
    int pageIndex = 1,
    int pageSize = 10,
    String? status,
    String? keyword,
    DateTime? fromDate,
    DateTime? toDate,
    bool admin = false,
  }) async {
    String ymd(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final query = <String, String>{
      'pageIndex': '$pageIndex',
      'pageSize': '$pageSize',
      if (status != null && status.isNotEmpty) 'status': status,
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword': keyword.trim(),
      if (fromDate != null) 'fromDate': ymd(fromDate),
      if (toDate != null) 'toDate': ymd(toDate),
    };
    final base = admin ? ApiConfig.adminOrders : ApiConfig.orders;
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}$base')
              .replace(queryParameters: query),
          headers: await ApiClient.authHeaders(json: true),
        )
        .timeout(ApiConfig.timeout);
    return PagedResultOrder.fromJson(
      ApiClient.unwrap(response) as Map<String, dynamic>,
    );
  }

  Future<OrderResponse> getOrderById(int id, {bool admin = false}) async {
    final base = admin ? ApiConfig.adminOrders : ApiConfig.orders;
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}$base/$id'),
          headers: await ApiClient.authHeaders(json: true),
        )
        .timeout(ApiConfig.timeout);
    return OrderResponse.fromJson(
      ApiClient.unwrap(response) as Map<String, dynamic>,
    );
  }

  Future<void> cancelOrder(int id) async {
    final response = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.orders}/$id/cancel'),
          headers: await ApiClient.authHeaders(json: true),
        )
        .timeout(ApiConfig.timeout);
    ApiClient.unwrap(response);
  }

  Future<String> confirmVietQrPayment(int id) async {
    final response = await _client
        .post(
          Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.orders}/$id/confirm-payment',
          ),
          headers: await ApiClient.authHeaders(json: true),
        )
        .timeout(ApiConfig.timeout);
    final data = ApiClient.unwrap(response);
    return data is Map && data['message'] is String
        ? data['message'] as String
        : 'Đã ghi nhận thông tin chuyển khoản.';
  }

  /// Admin: đổi trạng thái đơn (Pending/Confirmed/Processing/Shipped/Delivered/Cancelled/Returned).
  Future<String> updateOrderStatus(
    int id,
    String status, {
    String? note,
  }) async {
    final response = await _client
        .put(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.adminOrders}/$id/status'),
          headers: await ApiClient.authHeaders(json: true),
          body: jsonEncode({
            'status': status,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          }),
        )
        .timeout(ApiConfig.timeout);
    final data = ApiClient.unwrap(response);
    return data is Map && data['message'] is String
        ? data['message'] as String
        : 'Đã cập nhật trạng thái đơn hàng.';
  }
}
