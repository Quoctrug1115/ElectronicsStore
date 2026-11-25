import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/jwt_helper.dart';
import '../core/token_storage.dart';
import '../providers/cart_provider.dart';
import '../screens/auth/change_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/member/order_history_screen.dart';
import 'top_notice.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  String? _token;
  String? _email;
  String? _name;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final token = await TokenStorage.getToken();
    if (!mounted) return;
    final payload = token == null ? null : JwtHelper.decodePayload(token);
    setState(() {
      _token = token;
      _email = _claim(payload, const ['emailaddress', 'email']);
      _name = _claim(payload, const ['/name', 'name', 'unique_name']);
    });
  }

  String? _claim(Map<String, dynamic>? payload, List<String> suffixes) {
    if (payload == null) return null;
    for (final entry in payload.entries) {
      final key = entry.key.toLowerCase();
      for (final s in suffixes) {
        if ((key == s || key.endsWith(s)) &&
            entry.value is String &&
            (entry.value as String).isNotEmpty) {
          return entry.value as String;
        }
      }
    }
    return null;
  }

  Future<void> _openChangePassword() async {
    final token = _token ?? await TokenStorage.getToken();
    if (!mounted) return;
    if (token == null) {
      showTopNotice(context, 'Phiên đăng nhập đã hết, vui lòng đăng nhập lại.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangePasswordScreen(accessToken: token),
      ),
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final container = ProviderScope.containerOf(context);
    await TokenStorage.clear();
    // Bỏ giỏ khỏi bộ nhớ (vẫn còn trong SQLite cho lần đăng nhập sau).
    container.read(cartProvider.notifier).resetInMemory();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final roleLabel = widget.isAdmin ? 'Quản trị viên' : 'Thành viên';

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      widget.isAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.person_outline,
                      size: 32,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name ?? roleLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_email != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _email!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(roleLabel),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: scheme.primaryContainer,
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                if (!widget.isAdmin) ...[
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Lịch sử đơn hàng'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OrderHistoryScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                ],
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Đổi mật khẩu'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openChangePassword,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.logout, color: scheme.error),
                  title: Text(
                    'Đăng xuất',
                    style: TextStyle(color: scheme.error),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
