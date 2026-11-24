import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/order_models.dart';
import '../../services/order_service.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  final OrderService _orderService = OrderService();

  OrderResponse? _order;
  bool _isLoading = true;
  bool _isConfirmingPayment = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final order = await _orderService.getOrderById(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _confirmVietQrPayment() async {
    setState(() => _isConfirmingPayment = true);
    try {
      final msg = await _orderService.confirmVietQrPayment(widget.orderId);
      if (!mounted) return;
      setState(() => _isConfirmingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _loadOrder();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _isConfirmingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy đơn hàng?'),
        content: const Text(
          'Bạn có chắc chắn muốn hủy đơn hàng này? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _orderService.cancelOrder(widget.orderId);
      if (!mounted) return;
      await _loadOrder();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã hủy đơn hàng thành công')),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _copyText(String label, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Đã sao chép $label: $text')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đơn hàng')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildError()
          : _order == null
          ? const Center(child: Text('Không tìm thấy đơn hàng'))
          : RefreshIndicator(onRefresh: _loadOrder, child: _buildOrderDetail()),
    );
  }

  Widget _buildError() {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _loadOrder, child: const Text('Thử lại')),
      ],
    );
  }

  Widget _buildOrderDetail() {
    final order = _order!;
    final showVietQr =
        order.paymentMethod.toLowerCase() == 'vietqr' &&
        order.paymentStatus.toLowerCase() != 'completed' &&
        order.status.toLowerCase() != 'cancelled' &&
        order.status.toLowerCase() != 'returned' &&
        order.vietQrUrl != null &&
        order.vietQrUrl!.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(order),
        if (showVietQr) ...[
          const SizedBox(height: 16),
          _buildVietQrCard(order),
        ],
        const SizedBox(height: 16),
        _buildInfoSection('Thông tin người nhận', [
          _InfoRow(
            label: 'Họ tên',
            value: order.recipientName,
            icon: Icons.person_outline,
          ),
          _InfoRow(
            label: 'Số điện thoại',
            value: order.phoneNumber,
            icon: Icons.phone_outlined,
          ),
          _InfoRow(
            label: 'Địa chỉ giao hàng',
            value: order.shippingAddress,
            icon: Icons.location_on_outlined,
          ),
          if (order.note != null && order.note!.isNotEmpty)
            _InfoRow(
              label: 'Ghi chú',
              value: order.note!,
              icon: Icons.note_outlined,
            ),
        ]),
        const SizedBox(height: 16),
        _buildInfoSection('Thông tin đơn hàng', [
          _InfoRow(
            label: 'Mã đơn hàng',
            value: order.orderCode,
            icon: Icons.receipt_long,
          ),
          _InfoRow(
            label: 'Ngày đặt',
            value: formatDateTime(order.createdAt),
            icon: Icons.calendar_today_outlined,
          ),
          _InfoRow(
            label: 'Phương thức thanh toán',
            value: _paymentMethodLabel(order.paymentMethod),
            icon: Icons.payments_outlined,
          ),
          _InfoRow(
            label: 'Trạng thái thanh toán',
            value: _paymentStatusLabel(order.paymentStatus),
            icon: Icons.account_balance_wallet_outlined,
            valueStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: order.paymentStatus.toLowerCase() == 'completed'
                  ? Colors.green
                  : Colors.orange.shade800,
            ),
          ),
          _InfoRow(
            label: 'Trạng thái đơn hàng',
            value: order.statusDisplay,
            icon: Icons.info_outline,
            valueStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: order.statusColor,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _buildItemsSection(order),
        const SizedBox(height: 16),
        _buildPriceSummary(order),
        if (order.status.toLowerCase() == 'pending' ||
            order.status.toLowerCase() == 'confirmed')
          _buildCancelButton(),
      ],
    );
  }

  Widget _buildVietQrCard(OrderResponse order) {
    final theme = Theme.of(context);
    final bankId = order.vietQr?.bankId ?? 'MB';
    final accountNo = order.vietQr?.accountNo ?? '0909123456';
    final accountName = order.vietQr?.accountName ?? 'ELECTRONICS STORE';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_2, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Thanh toán chuyển khoản VietQR',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                order.vietQrUrl!,
                width: 240,
                height: 280,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    width: 240,
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Không tải được ảnh QR. Vui lòng chuyển khoản theo thông tin bên dưới.',
                  ),
                ),
              ),
            ),
            const Divider(height: 24),
            _buildTransferRow('Ngân hàng', bankId),
            _buildTransferRow(
              'Số tài khoản',
              accountNo,
              onCopy: () => _copyText('Số tài khoản', accountNo),
            ),
            _buildTransferRow('Chủ tài khoản', accountName),
            _buildTransferRow(
              'Số tiền',
              formatVnd(order.totalAmount),
              isHighlight: true,
            ),
            _buildTransferRow(
              'Nội dung CK',
              order.orderCode,
              isHighlight: true,
              onCopy: () => _copyText('Nội dung chuyển khoản', order.orderCode),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _isConfirmingPayment ? null : _confirmVietQrPayment,
              icon: _isConfirmingPayment
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.verified_outlined),
              label: const Text('Tôi đã chuyển khoản'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferRow(
    String label,
    String value, {
    bool isHighlight = false,
    VoidCallback? onCopy,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isHighlight
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isHighlight ? theme.colorScheme.primary : null,
                    ),
                  ),
                ),
                if (onCopy != null)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Sao chép',
                    onPressed: onCopy,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _paymentMethodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'vietqr':
        return 'Chuyển khoản ngân hàng (VietQR)';
      case 'cod':
        return 'Thanh toán khi nhận hàng (COD)';
      case 'banktransfer':
        return 'Chuyển khoản ngân hàng';
      default:
        return method;
    }
  }

  String _paymentStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Đã thanh toán';
      case 'pending':
        return 'Chờ thanh toán';
      case 'failed':
        return 'Đã hủy / Thất bại';
      case 'refunded':
        return 'Đã hoàn tiền';
      default:
        return status;
    }
  }

  Widget _buildStatusCard(OrderResponse order) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: order.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(order.status),
                    color: order.statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.statusDisplay,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: order.statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mã đơn: ${order.orderCode}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimeline(order),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(OrderResponse order) {
    final theme = Theme.of(context);
    final statuses = [
      ('pending', 'Chờ xác nhận'),
      ('confirmed', 'Đã xác nhận'),
      ('processing', 'Đang xử lý'),
      ('shipping', 'Đang giao'),
      ('delivered', 'Đã giao'),
    ];

    final normalizedStatus = order.status.toLowerCase() == 'shipped'
        ? 'shipping'
        : order.status.toLowerCase();
    final currentIndex = statuses.indexWhere((s) => s.$1 == normalizedStatus);

    return Column(
      children: List.generate(statuses.length, (index) {
        final isCompleted = index <= currentIndex;
        final isCurrent =
            index == currentIndex && order.status.toLowerCase() != 'cancelled';
        final isLast = index == statuses.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? order.statusColor
                        : theme.colorScheme.outlineVariant,
                    border: Border.all(
                      color: isCompleted
                          ? order.statusColor
                          : theme.colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: index < currentIndex
                        ? order.statusColor
                        : theme.colorScheme.outlineVariant,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statuses[index].$2,
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isCompleted
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isCurrent)
                      Text(
                        'Trạng thái hiện tại',
                        style: TextStyle(
                          fontSize: 12,
                          color: order.statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'confirmed':
        return Icons.verified;
      case 'processing':
        return Icons.settings;
      case 'shipped':
      case 'shipping':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildInfoSection(String title, List<_InfoRow> rows) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      row.icon,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            row.value,
                            style: row.valueStyle ?? theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(OrderResponse order) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sản phẩm (${order.items.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...order.items.map((item) => _buildOrderItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrderItemResponse item) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child: item.fullImageUrl.isNotEmpty
                  ? Image.network(
                      item.fullImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(theme),
                    )
                  : _placeholder(theme),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.variantInfo != null && item.variantInfo!.isNotEmpty)
                  Text(
                    item.variantInfo!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${formatVnd(item.unitPrice)} x ${item.quantity}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Text(
            formatVnd(item.totalPrice),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary(OrderResponse order) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _PriceRow(label: 'Tạm tính', value: formatVnd(order.totalAmount)),
            const SizedBox(height: 8),
            _PriceRow(
              label: 'Phí vận chuyển',
              value: 'Miễn phí',
              valueStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(height: 24),
            _PriceRow(
              label: 'Tổng cộng',
              value: formatVnd(order.totalAmount),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: OutlinedButton.icon(
        onPressed: _cancelOrder,
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Hủy đơn hàng'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.devices, color: theme.colorScheme.outline, size: 24),
    );
  }

  String formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow {
  final String label;
  final String value;
  final IconData icon;
  final TextStyle? valueStyle;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueStyle,
  });
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final TextStyle? valueStyle;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )
              : theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: isTotal
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                )
              : valueStyle ??
                    theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
        ),
      ],
    );
  }
}
