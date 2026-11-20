import 'package:flutter/material.dart';

import '../../core/api_config.dart';

class OrderItemRequest {
  final int productId;
  final int? variantId;
  final int quantity;

  const OrderItemRequest({
    required this.productId,
    this.variantId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    if (variantId != null) 'variantId': variantId,
    'quantity': quantity,
  };
}

class CreateOrderRequest {
  final String recipientName;
  final String phoneNumber;
  final String shippingAddress;
  final String paymentMethod;
  final double shippingFee;
  final String? note;
  final List<OrderItemRequest> items;

  const CreateOrderRequest({
    required this.recipientName,
    required this.phoneNumber,
    required this.shippingAddress,
    this.paymentMethod = 'COD',
    this.shippingFee = 0,
    this.note,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'recipientName': recipientName,
    'phoneNumber': phoneNumber,
    'shippingAddress': shippingAddress,
    'paymentMethod': paymentMethod,
    'shippingFee': shippingFee,
    if (note != null && note!.isNotEmpty) 'note': note,
  };
}

class OrderResponse {
  final int id;
  final String orderCode;
  final String status;
  final String recipientName;
  final String phoneNumber;
  final String shippingAddress;
  final String? note;
  final double totalAmount;
  final DateTime createdAt;
  final List<OrderItemResponse> items;

  const OrderResponse({
    required this.id,
    required this.orderCode,
    required this.status,
    required this.recipientName,
    required this.phoneNumber,
    required this.shippingAddress,
    this.note,
    required this.totalAmount,
    required this.createdAt,
    this.items = const [],
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) => OrderResponse(
    id: (json['id'] as num).toInt(),
    orderCode: json['orderCode'] as String? ?? '',
    status: json['status'] as String? ?? '',
    recipientName: json['recipientName'] as String? ?? '',
    phoneNumber: json['phoneNumber'] as String? ?? '',
    shippingAddress: json['shippingAddress'] as String? ?? '',
    note: json['note'] as String?,
    totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    items: (json['items'] as List<dynamic>? ?? [])
        .map((e) => OrderItemResponse.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'processing':
        return 'Đang xử lý';
      case 'shipped':
      case 'shipping':
        return 'Đang giao';
      case 'delivered':
        return 'Đã giao';
      case 'cancelled':
        return 'Đã hủy';
      case 'returned':
        return 'Đã trả hàng';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'processing':
        return Colors.blue;
      case 'shipped':
      case 'shipping':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'returned':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class OrderItemResponse {
  final int id;
  final int productId;
  final String productName;
  final String? variantInfo;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? productImageUrl;

  const OrderItemResponse({
    required this.id,
    required this.productId,
    required this.productName,
    this.variantInfo,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.productImageUrl,
  });

  String get fullImageUrl {
    if (productImageUrl == null || productImageUrl!.isEmpty) return '';
    if (productImageUrl!.startsWith('http')) return productImageUrl!;
    return '${ApiConfig.baseUrl}$productImageUrl';
  }

  factory OrderItemResponse.fromJson(Map<String, dynamic> json) {
    final color = json['color'] as String?;
    final storage = json['storage'] as String?;
    final parts = [
      if (color != null && color.isNotEmpty) color,
      if (storage != null && storage.isNotEmpty) storage,
    ];

    return OrderItemResponse(
      id: (json['id'] as num).toInt(),
      productId: (json['productId'] as num?)?.toInt() ?? 0,
      productName: json['productName'] as String? ?? '',
      variantInfo: json['variantInfo'] as String? ??
          (parts.isNotEmpty ? parts.join(' - ') : null),
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      productImageUrl:
          (json['primaryImageUrl'] ?? json['productImageUrl']) as String?,
    );
  }
}

class PagedResultOrder {
  final List<OrderResponse> items;
  final int totalCount;
  final int pageIndex;
  final int pageSize;

  const PagedResultOrder({
    required this.items,
    required this.totalCount,
    required this.pageIndex,
    required this.pageSize,
  });

  int get totalPages => pageSize > 0 ? (totalCount / pageSize).ceil() : 0;
  bool get hasNextPage => pageIndex < totalPages;
  bool get hasPreviousPage => pageIndex > 1;

  factory PagedResultOrder.fromJson(
    Map<String, dynamic> json,
  ) => PagedResultOrder(
    items: (json['items'] as List<dynamic>? ?? [])
        .map((e) => OrderResponse.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalCount: (json['totalCount'] as num).toInt(),
    pageIndex: (json['pageIndex'] as num).toInt(),
    pageSize: (json['pageSize'] as num).toInt(),
  );
}