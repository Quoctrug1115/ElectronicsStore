import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../admin/brand_list_screen.dart';
import '../admin/category_list_screen.dart';
import '../admin/product_list_screen.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang Admin'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              size: 80,
              color: Colors.indigo,
            ),
            const SizedBox(height: 16),
            Text('Chào Admin',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Bạn có toàn quyền quản lý hệ thống.'),
            const SizedBox(height: 40),
            _adminCard(
              context,
              icon: Icons.category,
              label: 'Quản lý Danh mục',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CategoryListScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _adminCard(
              context,
              icon: Icons.inventory,
              label: 'Quản lý Sản phẩm',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProductListScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _adminCard(
              context,
              icon: Icons.business,
              label: 'Quản lý Thương hiệu',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BrandListScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.indigo.shade100,
            child: Icon(icon, color: Colors.indigo),
          ),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
