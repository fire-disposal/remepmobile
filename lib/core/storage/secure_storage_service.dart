import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全存储服务
/// 用于存储敏感数据，如Token、密码等
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        );

  /// 读取数据
  Future<String?> read({required String key}) async {
    return _storage.read(key: key);
  }

  /// 写入数据
  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  /// 删除数据
  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  /// 删除所有数据
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// 检查key是否存在
  Future<bool> containsKey({required String key}) async {
    return _storage.containsKey(key: key);
  }

  /// 读取所有数据
  Future<Map<String, String>> readAll() async {
    return _storage.readAll();
  }
}