import '../core/format.dart';

class DailyRevenue {
  final DateTime date;
  final double revenue;
  final int orders;

  const DailyRevenue({
    required this.date,
    required this.revenue,
    required this.orders,
  });

  factory DailyRevenue.fromJson(Map<String, dynamic> json) {
    // "yyyy-MM-dd" là ngày theo múi giờ của máy, không phải thời điểm UTC nên không dùng parseServerDate.
    final parts = (json['date'] as String? ?? '').split('-');
    final date = parts.length == 3
        ? DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          )
        : parseServerDate(json['date']) ?? DateTime.now();
    return DailyRevenue(
      date: date,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      orders: (json['orders'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Thống kê doanh thu cho màn Tổng quan (`GET /api/admin/stats/revenue`).
/// Doanh thu = tổng tiền các đơn đã giao.
class RevenueStats {
  final double totalRevenue;
  final int deliveredOrders;
  final double todayRevenue;
  final int todayOrders;
  final double monthRevenue;
  final int monthOrders;
  final double inProgressRevenue;
  final int inProgressOrders;
  final int cancelledOrders;
  final List<DailyRevenue> daily;

  const RevenueStats({
    required this.totalRevenue,
    required this.deliveredOrders,
    required this.todayRevenue,
    required this.todayOrders,
    required this.monthRevenue,
    required this.monthOrders,
    required this.inProgressRevenue,
    required this.inProgressOrders,
    required this.cancelledOrders,
    required this.daily,
  });

  factory RevenueStats.fromJson(Map<String, dynamic> json) {
    double d(String k) => (json[k] as num?)?.toDouble() ?? 0;
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    return RevenueStats(
      totalRevenue: d('totalRevenue'),
      deliveredOrders: i('deliveredOrders'),
      todayRevenue: d('todayRevenue'),
      todayOrders: i('todayOrders'),
      monthRevenue: d('monthRevenue'),
      monthOrders: i('monthOrders'),
      inProgressRevenue: d('inProgressRevenue'),
      inProgressOrders: i('inProgressOrders'),
      cancelledOrders: i('cancelledOrders'),
      daily: (json['dailyRevenue'] as List<dynamic>? ?? [])
          .map((e) => DailyRevenue.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
