import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/cart_provider.dart';
import '../../widgets/account_tab.dart';
import '../member/cart_screen.dart';
import '../home/home_screen.dart';

class MemberHome extends ConsumerStatefulWidget {
  MemberHome({super.key});

  @override
  ConsumerState<MemberHome> createState() => _MemberHomeState();
}

class _MemberHomeState extends ConsumerState<MemberHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cartQuantity = ref.watch(cartTotalQuantityProvider);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          CartScreen(),
          AccountTab(isAdmin: false),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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