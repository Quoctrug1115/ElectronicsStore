class RegisterRequest {
  final String fullName;
  final String email;
  final String password;
  final String? phoneNumber;

  const RegisterRequest({
    required this.fullName,
    required this.email,
    required this.password,
    this.phoneNumber,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'email': email,
    'password': password,
    'phoneNumber': phoneNumber,
  };
}

class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class ChangePasswordRequest {
  final String oldPassword;
  final String newPassword;
  final String confirmNewPassword;

  const ChangePasswordRequest({
    required this.oldPassword,
    required this.newPassword,
    required this.confirmNewPassword,
  });

  Map<String, dynamic> toJson() => {
    'oldPassword': oldPassword,
    'newPassword': newPassword,
    'confirmNewPassword': confirmNewPassword,
  };
}

class UserInfo {
  final int id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final List<String> roles;

  const UserInfo({
    required this.id,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.roles = const [],
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    id: (json['id'] as num).toInt(),
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phoneNumber: json['phoneNumber'] as String?,
    roles: (json['roles'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(),
  );
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final UserInfo user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String? ?? '',
    expiresAt:
        DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
        DateTime.now(),
    user: UserInfo.fromJson(json['user'] as Map<String, dynamic>),
  );
}
