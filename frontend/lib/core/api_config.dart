class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5202',
  );

  static const Duration timeout = Duration(seconds: 15);

  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String googleLogin = '/api/auth/google';
  static const String zaloLogin = '/api/auth/zalo';
  static const String facebookLogin = '/api/auth/facebook';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
  static const String sendVerificationOtp = '/api/auth/send-verification-otp';
  static const String verifyEmail = '/api/auth/verify-email';
  static const String changePassword = '/api/auth/change-password';
  static const String categories = '/api/categories';
  static const String brands = '/api/brands';
  static const String products = '/api/products';
  static const String orders = '/api/orders';
  static const String adminOrders = '/api/admin/orders';
  static const String adminUsers = '/api/admin/users';
  static const String adminRevenue = '/api/admin/stats/revenue';
}
