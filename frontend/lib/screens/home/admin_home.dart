import 'package:flutter/material.dart';

import '../../widgets/account_tab.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/brand_list_screen.dart';
import '../admin/category_list_screen.dart';
import '../admin/product_list_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;
  final Set<int> _visited = {0};

  // Đổi key để buộc tab tải lại dữ liệu khi cần.
  int _dashboardKey = 0;
  int _listsKey = 0;

  void _select(int i) {
    setState(() {
      if (i == 0 && _index != 0) _dashboardKey++;
      _index = i;
      _visited.add(i);
    });
  }

  Widget _tab(int i) {
    if (!_visited.contains(i)) return const SizedBox.shrink();
    switch (i) {
      case 0:
        return AdminDashboardScreen(
          key: ValueKey('dash$_dashboardKey'),
          onNavigate: _select,
          onDataChanged: () => setState(() => _listsKey++),
        );
      case 1:
        return ProductListScreen(key: ValueKey('products$_listsKey'));
      case 2:
        return CategoryListScreen(key: ValueKey('categories$_listsKey'));
      case 3:
        return BrandListScreen(key: ValueKey('brands$_listsKey'));
      default:
        return const AccountTab(isAdmin: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < 5; i++) _tab(i)],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Sản phẩm',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Danh mục',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Thương hiệu',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
