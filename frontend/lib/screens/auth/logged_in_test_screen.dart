import 'package:flutter/material.dart';

import '../../models/auth_models.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

/// TODO (Lê Thịnh): Thay bằng AdminHome / MemberHome theo Claim Role rồi xóa file này.
class LoggedInTestScreen extends StatelessWidget {
  const LoggedInTestScreen({super.key, required this.authResponse});

  final AuthResponse authResponse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = authResponse.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng nhập thành công'),
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
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào, ${user.fullName}',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Email: ${user.email}'),
                  if (user.phoneNumber != null)
                    Text('Số điện thoại: ${user.phoneNumber}'),
                  Text('Vai trò: ${user.roles.join(', ')}'),
                  Text('Token hết hạn: ${authResponse.expiresAt.toLocal()}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.password),
            label: const Text('Đổi mật khẩu'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ChangePasswordScreen(accessToken: authResponse.accessToken),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
