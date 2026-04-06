import 'dart:async';

/// 定义获取身份验证令牌的接口。
abstract class AuthTokenProvider {
  /// 获取当前的访问令牌。
  FutureOr<String?> getAccessToken();

  /// 获取当前的刷新令牌（可选）。
  FutureOr<String?> getRefreshToken() => null;

  /// 清除令牌信息。
  Future<void> clearTokens();
}
