/// 认证仓库接口
abstract class AuthRepository {
  /// 登录
  Future<AuthResult> login({
    required String email,
    required String password,
  });

  /// 注册
  Future<AuthResult> register({
    required String email,
    required String password,
    required String confirmPassword,
  });

  /// 退出登录
  Future<void> logout();

  /// 检查是否已登录
  Future<bool> isLoggedIn();

  /// 获取当前Token
  Future<String?> getToken();

  /// 刷新Token
  Future<AuthResult> refreshToken();
}

/// 认证结果
class AuthResult {
  final bool success;
  final String? token;
  final String? refreshToken;
  final String? error;
  final User? user;

  const AuthResult({
    required this.success,
    this.token,
    this.refreshToken,
    this.error,
    this.user,
  });

  factory AuthResult.success({
    String? token,
    String? refreshToken,
    User? user,
  }) {
    return AuthResult(
      success: true,
      token: token,
      refreshToken: refreshToken,
      user: user,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult(
      success: false,
      error: error,
    );
  }
}

/// 用户信息
class User {
  final String id;
  final String email;
  final String? name;
  final String? avatar;

  const User({
    required this.id,
    required this.email,
    this.name,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'avatar': avatar,
      };
}