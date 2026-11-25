import '../core/format.dart';

/// Người dùng trong màn quản trị (`GET /api/admin/users`).
class AdminUser {
  final int id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final bool emailConfirmed;
  final bool isLocked;
  final String role;
  final DateTime createdAt;

  const AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    required this.emailConfirmed,
    required this.isLocked,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == 'Admin';

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: (json['id'] as num).toInt(),
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phoneNumber: json['phoneNumber'] as String?,
    emailConfirmed: json['emailConfirmed'] as bool? ?? false,
    isLocked: json['isLocked'] as bool? ?? false,
    role: json['role'] as String? ?? 'Member',
    createdAt:
        parseServerDate(json['createdAt']) ??
        DateTime.now(),
  );
}

class PagedAdminUsers {
  final List<AdminUser> items;
  final int totalCount;
  final int pageIndex;
  final int pageSize;

  const PagedAdminUsers({
    required this.items,
    required this.totalCount,
    required this.pageIndex,
    required this.pageSize,
  });

  int get totalPages => pageSize > 0 ? (totalCount / pageSize).ceil() : 0;
  bool get hasNextPage => pageIndex < totalPages;
  bool get hasPreviousPage => pageIndex > 1;

  factory PagedAdminUsers.fromJson(Map<String, dynamic> json) =>
      PagedAdminUsers(
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalCount: (json['totalCount'] as num).toInt(),
        pageIndex: (json['pageIndex'] as num).toInt(),
        pageSize: (json['pageSize'] as num).toInt(),
      );
}

class UserOrderSummary {
  final int id;
  final String orderCode;
  final String status;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime createdAt;

  const UserOrderSummary({
    required this.id,
    required this.orderCode,
    required this.status,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
  });

  factory UserOrderSummary.fromJson(Map<String, dynamic> json) =>
      UserOrderSummary(
        id: (json['id'] as num).toInt(),
        orderCode: json['orderCode'] as String? ?? '',
        status: json['status'] as String? ?? '',
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
        paymentMethod: json['paymentMethod'] as String? ?? 'COD',
        paymentStatus: json['paymentStatus'] as String? ?? 'Pending',
        createdAt:
            parseServerDate(json['createdAt']) ??
            DateTime.now(),
      );
}

/// Chi tiết người dùng + thống kê hoạt động (`GET /api/admin/users/{id}`).
class AdminUserDetail {
  final AdminUser user;
  final int orderCount;
  final double totalSpent;
  final DateTime? lastOrderAt;
  final DateTime? lastLoginAt;
  final int loginCount;
  final int cartItemCount;
  final Map<String, int> ordersByStatus;
  final List<UserOrderSummary> recentOrders;

  const AdminUserDetail({
    required this.user,
    required this.orderCount,
    required this.totalSpent,
    this.lastOrderAt,
    this.lastLoginAt,
    required this.loginCount,
    required this.cartItemCount,
    required this.ordersByStatus,
    required this.recentOrders,
  });

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) =>
        parseServerDate(json[key]);
    final byStatus = (json['ordersByStatus'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, (v as num).toInt()));
    return AdminUserDetail(
      user: AdminUser.fromJson(json),
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0,
      lastOrderAt: date('lastOrderAt'),
      lastLoginAt: date('lastLoginAt'),
      loginCount: (json['loginCount'] as num?)?.toInt() ?? 0,
      cartItemCount: (json['cartItemCount'] as num?)?.toInt() ?? 0,
      ordersByStatus: byStatus,
      recentOrders: (json['recentOrders'] as List<dynamic>? ?? [])
          .map((e) => UserOrderSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
