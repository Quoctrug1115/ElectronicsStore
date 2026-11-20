import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/token_storage.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/admin_home.dart';
import 'screens/home/member_home.dart';

void main() {
  runApp(const ProviderScope(child: ElectronicsStoreApp()));
}

class ElectronicsStoreApp extends StatelessWidget {
  const ElectronicsStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Electronics Store',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  String? _route;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final token = await TokenStorage.getToken();
    final roles = await TokenStorage.getRoles();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _route = token != null
          ? (roles.contains('Admin') ? '/admin' : '/member')
          : '/login';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    switch (_route) {
      case '/admin':
        return const AdminHome();
      case '/member':
        return MemberHome();
      default:
        return const LoginScreen();
    }
  }
}
