import 'dart:async';
import '../storage/secure_storage_service.dart';
import 'auth_token_provider.dart';

/// 使用 SecureStorageService 实现的 AuthTokenProvider。
class StorageAuthTokenProvider implements AuthTokenProvider {
  StorageAuthTokenProvider(this._secureStorage);

  final SecureStorageService _secureStorage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  @override
  FutureOr<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  @override
  FutureOr<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  /// 存储新令牌。
  Future<void> saveTokens({required String access, String? refresh}) async {
    await _secureStorage.write(key: _accessTokenKey, value: access);
    if (refresh != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: refresh);
    }
  }
}
