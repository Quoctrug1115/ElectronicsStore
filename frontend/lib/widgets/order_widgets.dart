import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/order_models.dart';

/// Các trạng thái dùng để lọc đơn: (nhãn, giá trị gửi API; '' = tất cả).
const orderStatusFilters = <(String, String)>[
  ('Tất cả', ''),
  ('Chờ xác nhận', 'pending'),
  ('Đã xác nhận', 'confirmed'),
  ('Đang xử lý', 'processing'),
  ('Đang giao', 'shipped'),
  ('Đã giao', 'delivered'),
  ('Đã hủy', 'cancelled'),
  ('Đã trả hàng', 'returned'),
];

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.order});

  final OrderResponse order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: order.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        order.statusDisplay,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: order.statusColor,
        ),
      ),
    );
  }
}

/// Thanh tìm kiếm mã đơn + khoảng ngày + chip trạng thái (dùng cho lịch sử đơn của khách và quản lý đơn của Admin).
class OrderFilterBar extends StatefulWidget {
  const OrderFilterBar({
    super.key,
    required this.status,
    required this.dateRange,
    required this.onKeyword,
    required this.onStatus,
    required this.onDateRange,
    this.hint = 'Tìm theo mã đơn',
  });

  final String status;
  final DateTimeRange? dateRange;
  final ValueChanged<String> onKeyword;
  final ValueChanged<String> onStatus;
  final ValueChanged<DateTimeRange?> onDateRange;
  final String hint;

  @override
  State<OrderFilterBar> createState() => _OrderFilterBarState();
}

class _OrderFilterBarState extends State<OrderFilterBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: widget.dateRange,
      helpText: 'Lọc theo ngày đặt',
    );
    if (picked != null) widget.onDateRange(picked);
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.dateRange;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Lọc theo ngày',
                icon: Icon(
                  range == null ? Icons.date_range_outlined : Icons.date_range,
                ),
                onPressed: _pickRange,
              ),
            ),
            onSubmitted: widget.onKeyword,
          ),
          if (range != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InputChip(
                label: Text(
                  '${formatDate(range.start)} - ${formatDate(range.end)}',
                ),
                onDeleted: () => widget.onDateRange(null),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (label, value) in orderStatusFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: widget.status == value,
                      onSelected: (_) => widget.onStatus(value),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ tóm tắt một đơn hàng. [showCustomer] hiện tên/email khách (màn Admin).
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showCustomer = false,
  });

  final OrderResponse order;
  final VoidCallback onTap;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderCode,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OrderStatusChip(order: order),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Ngày đặt: ${formatDateTime(order.createdAt)}',
                style: muted,
              ),
              if (showCustomer && order.customerName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Khách: ${order.customerName} · ${order.customerEmail ?? ''}',
                  style: muted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      order.recipientName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.phone_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text(order.phoneNumber, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.shippingAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                'Tổng cộng: ${formatVnd(order.totalAmount)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
