import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/top_notice.dart';

enum OtpPurpose { resetPassword, verifyEmail }

/// Màn OTP qua email dùng chung cho "Quên mật khẩu" và "Xác thực email".
/// Pop về `true` khi hoàn tất.
class EmailOtpScreen extends StatefulWidget {
  const EmailOtpScreen({
    super.key,
    required this.purpose,
    this.initialEmail,
    this.otpAlreadySent = false,
  });

  final OtpPurpose purpose;
  final String? initialEmail;

  /// true khi server đã gửi OTP trước đó (ví dụ vừa đăng ký) nên chỉ cần nhập mã.
  final bool otpAlreadySent;

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  static const _cooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  bool get _isReset => widget.purpose == OtpPurpose.resetPassword;

  bool _isLoading = false;
  bool _obscure = true;
  String? _errorMessage;
  String? _infoMessage;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.otpAlreadySent) _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Vui lòng nhập email';
    if (!emailRegex.hasMatch(value)) return 'Email không đúng định dạng';
    return null;
  }

  Future<void> _guard(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    final emailError = _validateEmail(_emailController.text);
    if (emailError != null) {
      setState(() => _errorMessage = emailError);
      return;
    }
    await _guard(() async {
      final email = _emailController.text.trim();
      final msg = _isReset
          ? await _authService.forgotPassword(email)
          : await _authService.sendVerificationOtp(email);
      if (!mounted) return;
      setState(() => _infoMessage = msg);
      _startCooldown();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _guard(() async {
      final email = _emailController.text.trim();
      final otp = _otpController.text.trim();
      final msg = _isReset
          ? await _authService.resetPassword(
              email: email,
              otp: otp,
              newPassword: _passwordController.text,
              confirmNewPassword: _confirmController.text,
            )
          : await _authService.verifyEmail(email: email, otp: otp);
      if (!mounted) return;
      showTopNotice(context, msg);
      Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _isReset ? 'Quên mật khẩu' : 'Xác thực email';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isReset
                          ? 'Nhập email, bấm "Gửi mã" rồi nhập mã OTP 6 số cùng mật khẩu mới.'
                          : 'Nhập mã OTP 6 số đã gửi tới email của bạn để kích hoạt tài khoản.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: (_isLoading || _cooldown > 0)
                            ? null
                            : _sendOtp,
                        child: Text(
                          _cooldown > 0
                              ? 'Gửi lại mã sau ${_cooldown}s'
                              : (widget.otpAlreadySent || _infoMessage != null
                                    ? 'Gửi lại mã'
                                    : 'Gửi mã'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Mã OTP (6 số)',
                        prefixIcon: Icon(Icons.pin_outlined),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: (v) =>
                          RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Mã OTP phải gồm đúng 6 chữ số',
                    ),
                    if (_isReset) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Mật khẩu mới tối thiểu 6 ký tự'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscure,
                        enabled: !_isLoading,
                        decoration: const InputDecoration(
                          labelText: 'Xác nhận mật khẩu mới',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v != _passwordController.text
                            ? 'Xác nhận mật khẩu không khớp'
                            : null,
                      ),
                    ],
                    if (_infoMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _infoMessage!,
                        style: TextStyle(color: Colors.green.shade800),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      ErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(_isReset ? 'Đặt lại mật khẩu' : 'Xác thực'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
