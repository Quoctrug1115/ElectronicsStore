import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/local_database.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/account_tab.dart';
import '../../widgets/top_notice.dart';
import '../member/cart_screen.dart';
import '../home/home_screen.dart';

class MemberHome extends ConsumerStatefulWidget {
  const MemberHome({super.key});

  @override
  ConsumerState<MemberHome> createState() => _MemberHomeState();
}

class _MemberHomeState extends ConsumerState<MemberHome> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    LocalDatabase.offline.addListener(_onOfflineChanged);
    // Giỏ hàng lưu trong SQLite: nạp lại giỏ của tài khoản đang đăng nhập.
    ref.read(cartProvider.notifier).loadForCurrentUser();
  }

  @override
  void dispose() {
    LocalDatabase.offline.removeListener(_onOfflineChanged);
    super.dispose();
  }

  /// Báo cho người dùng biết khi app chuyển sang xem dữ liệu đã lưu trong SQLite (mất mạng) và khi có mạng lại.
  void _onOfflineChanged() {
    if (!mounted) return;
    if (LocalDatabase.offline.value) {
      showTopNotice(
        context,
        'Không có kết nối mạng. Đang hiển thị dữ liệu đã lưu trên máy.',
        isError: true,
        duration: const Duration(seconds: 4),
      );
    } else {
      showTopNotice(context, 'Đã kết nối lại, dữ liệu đã được cập nhật.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartQuantity = ref.watch(cartTotalQuantityProvider);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onOpenCart: () => setState(() => _index = 1),
          ),
          CartScreen(
            onContinueShopping: () => setState(() => _index = 0),
          ),
          AccountTab(isAdmin: false),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          // Thông báo của màn khác không nên nằm lại khi đổi tab.
          hideTopNotice();
          setState(() => _index = i);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Sản phẩm',
          ),
          NavigationDestination(
            icon: _buildCartBadge(cartQuantity, false),
            selectedIcon: _buildCartBadge(cartQuantity, true),
            label: 'Giỏ hàng',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }

  Widget _buildCartBadge(int quantity, bool selected) {
    return Badge(
      isLabelVisible: quantity > 0,
      label: quantity > 99 ? const Text('99+') : Text('$quantity'),
      child: Icon(selected ? Icons.shopping_cart : Icons.shopping_cart_outlined),
    );
  }
}