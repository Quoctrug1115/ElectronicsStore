import 'package:flutter/material.dart';

import '../auth/login_screen.dart';

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
            Text('Chào Member', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Bạn có thể duyệt và mua sản phẩm.'),
          ],
        ),
      ),
    );
  }
}
