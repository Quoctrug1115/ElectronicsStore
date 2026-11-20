import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/cart_models.dart';
import '../../models/order_models.dart';
import '../../providers/cart_provider.dart';
import '../../services/order_service.dart';
import '../home/member_home.dart';
import 'order_history_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    // Placeholder for loading user info from backend
    // Fields will be filled by user input
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orderService = OrderService();
      final request = CreateOrderRequest(
        recipientName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        shippingAddress: _addressController.text.trim(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        items: cart.items.map((item) => OrderItemRequest(
          productId: item.product.id,
          variantId: item.variant?.id,
          quantity: item.quantity,
        )).toList(),
      );

      final order = await orderService.createOrder(request);

      if (!mounted) return;

      ref.read(cartProvider.notifier).clear();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(order: order),
        ),
        (route) => route.isFirst,
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Xác nhận đặt hàng')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 64),
              const SizedBox(height: 16),
              const Text('Giỏ hàng trống'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay lại giỏ hàng'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đặt hàng')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Thông tin người nhận'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Họ và tên',
                      hint: 'Nguyễn Văn A',
                      validator: (v) => v?.trim().isEmpty == true ? 'Vui lòng nhập họ tên' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Số điện thoại',
                      hint: '090 123 4567',
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v?.trim().isEmpty == true) return 'Vui lòng nhập số điện thoại';
                        final phone = v!.trim();
                        if (!RegExp(r'^(0|\+84)[3|5|7|8|9]\d{8}$').hasMatch(phone)) {
                          return 'Số điện thoại không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Địa chỉ giao hàng',
                      hint: 'Số nhà, đường, phường, quận, thành phố',
                      maxLines: 3,
                      validator: (v) => v?.trim().isEmpty == true ? 'Vui lòng nhập địa chỉ' : null,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Ghi chú đơn hàng (tùy chọn)'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _noteController,
                      label: 'Ghi chú',
                      hint: 'Yêu cầu đặc biệt về giao hàng, đóng gói...',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Đơn hàng'),
                    const SizedBox(height: 12),
                    ...cart.items.map((item) => _buildOrderItem(item)).toList(),
                    const SizedBox(height: 12),
                    _buildOrderSummary(cart),
                  ],
                ),
              ),
            ),
            _buildBottomBar(cart),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildOrderItem(CartItem item) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (item.variantInfo.isNotEmpty)
                    Text(
                      item.variantInfo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatVnd(item.price)} x ${item.quantity}',
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
      ),
    );
  }

  Widget _buildOrderSummary(Cart cart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow('Tạm tính', formatVnd(cart.totalPrice)),
            const SizedBox(height: 8),
            _buildSummaryRow('Phí vận chuyển', 'Miễn phí', isHighlighted: true),
            const Divider(height: 24),
            _buildSummaryRow(
              'Tổng cộng',
              formatVnd(cart.totalPrice),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, bool isHighlighted = false}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
              : theme.textTheme.bodyMedium?.copyWith(
                  color: isHighlighted ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
        ),
        Text(
          value,
          style: isTotal
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                  color: isHighlighted ? theme.colorScheme.primary : null,
                ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(Cart cart) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: FilledButton(
          onPressed: _isLoading ? null : _submitOrder,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Đặt hàng - ${formatVnd(cart.totalPrice)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
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
}

class OrderSuccessScreen extends StatelessWidget {
  final OrderResponse order;

  const OrderSuccessScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt hàng thành công'), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 96, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Đặt hàng thành công!',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Mã đơn hàng: ${order.orderCode}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => OrderHistoryScreen()),
                    (route) => route.isFirst,
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('Xem lịch sử đơn hàng'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => MemberHome()),
                    (route) => route.isFirst,
                  );
                },
                child: const Text('Tiếp tục mua sắm'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}