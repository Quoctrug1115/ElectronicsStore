import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/admin_user_models.dart';
import '../../models/order_models.dart';
import '../../services/admin_user_service.dart';
import '../../widgets/admin_widgets.dart';
import '../member/order_detail_screen.dart';

/// Admin: thông tin tài khoản + hoạt động (đơn hàng, đăng nhập, giỏ hàng) của một người dùng.
class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.userId, this.title});

  final int userId;
  final String? title;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _service = AdminUserService();

  AdminUserDetail? _detail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final detail = await _service.getUserDetail(widget.userId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Chi tiết người dùng')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading && detail == null
            ? const Center(child: CircularProgressIndicator())
            : detail == null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ErrorRetry(
                    message: _errorMessage ?? 'Không tải được dữ liệu.',
                    onRetry: _load,
                  ),
                ],
              )
            : _buildContent(detail),
      ),
    );
  }

  Widget _buildContent(AdminUserDetail d) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final u = d.user;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: u.isAdmin
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  child: Icon(
                    u.isAdmin
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.fullName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        u.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text(u.role),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide.none,
                            backgroundColor: scheme.primaryContainer,
                          ),
                          StatusPill(isActive: !u.isLocked),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _section('Thông tin tài khoản', [
          _row(
            Icons.phone_outlined,
            'Số điện thoại',
            u.phoneNumber ?? 'Chưa cập nhật',
          ),
          _row(
            Icons.mark_email_read_outlined,
            'Email',
            u.emailConfirmed ? 'Đã xác thực' : 'Chưa xác thực',
          ),
          _row(
            Icons.event_outlined,
            'Ngày tham gia',
            formatDateTime(u.createdAt),
          ),
          _row(
            Icons.login,
            'Đăng nhập gần nhất',
            d.lastLoginAt == null ? 'Chưa có' : formatDateTime(d.lastLoginAt!),
          ),
          _row(Icons.history, 'Số lần đăng nhập', '${d.loginCount}'),
        ]),
        const SizedBox(height: 16),
        Text(
          'Hoạt động',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _stat(
                'Đơn hàng',
                '${d.orderCount}',
                Icons.receipt_long_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _stat(
                'Đã chi tiêu',
                formatVnd(d.totalSpent),
                Icons.payments_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _stat(
                'Trong giỏ hàng',
                '${d.cartItemCount} sản phẩm',
                Icons.shopping_cart_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _stat(
                'Đơn gần nhất',
                d.lastOrderAt == null ? 'Chưa có' : formatDate(d.lastOrderAt!),
                Icons.schedule,
              ),
            ),
          ],
        ),
        if (d.ordersByStatus.isNotEmpty) ...[
          const SizedBox(height: 16),
          _section('Đơn theo trạng thái', [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in d.ordersByStatus.entries)
                  Chip(
                    label: Text('${orderStatusLabel(e.key)}: ${e.value}'),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    backgroundColor: orderStatusColor(e.key)
                        .withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: orderStatusColor(e.key),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ]),
        ],
        const SizedBox(height: 16),
        Text(
          'Đơn hàng gần đây',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (d.recentOrders.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            message: 'Người dùng này chưa có đơn hàng.',
          )
        else
          for (final o in d.recentOrders) _orderTile(o),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
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
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderTile(UserOrderSummary o) {
    final theme = Theme.of(context);
    final color = orderStatusColor(o.status);
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: o.id, admin: true),
          ),
        ),
        title: Text(o.orderCode, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${formatDateTime(o.createdAt)}\n${formatVnd(o.totalAmount)}',
        ),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            orderStatusLabel(o.status),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
