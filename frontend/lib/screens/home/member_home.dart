import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../member/member_product_list_screen.dart';

class MemberHome extends StatelessWidget {
  const MemberHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang Thành viên'),
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
            const Icon(Icons.person, size: 80, color: Colors.indigo),
            const SizedBox(height: 16),
            Text('Chào Thành viên',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Bạn có thể duyệt và mua sản phẩm.'),
            const SizedBox(height: 40),
            _memberCard(
              context,
              icon: Icons.inventory,
              label: 'Danh sách Sản phẩm',
              subtitle: 'Xem và tìm kiếm sản phẩm',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MemberProductListScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _memberCard(
              context,
              icon: Icons.person_outline,
              label: 'Thông tin tài khoản',
              subtitle: 'Quản lý hồ sơ cá nhân',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chức năng đang phát triển.')),
                );
              },
            ),
            const SizedBox(height: 16),
            _memberCard(
              context,
              icon: Icons.shopping_cart_outlined,
              label: 'Giỏ hàng',
              subtitle: 'Quản lý sản phẩm đã chọn',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chức năng đang phát triển.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
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
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
