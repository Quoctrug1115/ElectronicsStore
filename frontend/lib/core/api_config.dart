class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5202',
  );

  static const Duration timeout = Duration(seconds: 15);

  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String changePassword = '/api/auth/change-password';
  static const String categories = '/api/categories';
  static const String brands = '/api/brands';
  static const String products = '/api/products';
  static const String orders = '/api/orders';
}
