import '../../constants/app_constants.dart';
import '../../storage/secure_storage_service.dart';
import 'auth_token_provider.dart';

/// 基于 SecureStorage 的 token 提供器。
class StorageAuthTokenProvider implements AuthTokenProvider {
  StorageAuthTokenProvider(this._secureStorage);

  final SecureStorageService _secureStorage;

  @override
  Future<String?> getToken() {
    return _secureStorage.read(key: AppConstants.tokenKey);
  }
}
