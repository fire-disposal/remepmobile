/// 统一的认证令牌读取接口，便于替换实现（本地缓存/内存/刷新策略）。
abstract class AuthTokenProvider {
  Future<String?> getToken();
}
