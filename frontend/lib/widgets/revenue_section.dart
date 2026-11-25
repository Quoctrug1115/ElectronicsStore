import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/revenue_models.dart';

/// Khối doanh thu ở màn Tổng quan: tổng, hôm nay, tháng này, dự kiến và biểu đồ cột theo ngày.
class RevenueSection extends StatelessWidget {
  const RevenueSection({super.key, required this.stats});

  final RevenueStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tổng doanh thu (đơn đã giao)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatVnd(stats.totalRevenue),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${stats.deliveredOrders} đơn đã giao',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _tile(
                context,
                'Hôm nay',
                formatVnd(stats.todayRevenue),
                '${stats.todayOrders} đơn',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tile(
                context,
                'Tháng này',
                formatVnd(stats.monthRevenue),
                '${stats.monthOrders} đơn',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _tile(
          context,
          'Dự kiến (đơn chưa giao xong)',
          formatVnd(stats.inProgressRevenue),
          '${stats.inProgressOrders} đơn đang xử lý · ${stats.cancelledOrders} đơn đã hủy',
        ),
        const SizedBox(height: 12),
        _RevenueChart(daily: stats.daily),
      ],
    );
  }

  Widget _tile(BuildContext context, String label, String value, String note) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.daily});

  final List<DailyRevenue> daily;

  static const double _barArea = 110;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxRevenue = daily.fold<double>(
      0,
      (m, d) => d.revenue > m ? d.revenue : m,
    );
    final empty = maxRevenue <= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Doanh thu ${daily.length} ngày gần đây',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _barArea + 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in daily)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: 18,
                              child: d.revenue > 0
                                  ? FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        formatVndShort(d.revenue),
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: d.revenue > 0
                                  ? (d.revenue / maxRevenue * _barArea).clamp(
                                      4.0,
                                      _barArea,
                                    )
                                  : 2,
                              decoration: BoxDecoration(
                                color: d.revenue > 0
                                    ? scheme.primary
                                    : scheme.outlineVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 16,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${d.date.day.toString().padLeft(2, '0')}/${d.date.month.toString().padLeft(2, '0')}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (empty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Chưa có đơn nào được giao trong giai đoạn này.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                'Doanh thu tính theo ngày giao hàng thành công.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
