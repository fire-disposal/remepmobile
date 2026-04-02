import 'package:hive_flutter/hive_flutter.dart';

/// 缓存存储服务
/// 用于存储非敏感数据，如用户偏好设置、缓存数据等
class CacheStorageService {
  static final CacheStorageService _instance = CacheStorageService._internal();
  factory CacheStorageService() => _instance;
  CacheStorageService._internal();

  static const String _defaultBoxName = 'app_cache';
  Box<dynamic>? _box;

  /// 初始化Hive
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_defaultBoxName);
  }

  /// 读取数据
  T? read<T>(String key) {
    return _box?.get(key) as T?;
  }

  /// 写入数据
  Future<void> write<T>(String key, T value) async {
    await _box?.put(key, value);
  }

  /// 删除数据
  Future<void> delete(String key) async {
    await _box?.delete(key);
  }

  /// 删除所有数据
  Future<void> deleteAll() async {
    await _box?.clear();
  }

  /// 检查key是否存在
  bool containsKey(String key) {
    return _box?.containsKey(key) ?? false;
  }

  /// 获取所有keys
  Iterable<String> get keys => _box?.keys.cast<String>() ?? const [];

  /// 获取数据条数
  int get length => _box?.length ?? 0;

  /// 监听数据变化
  Stream<BoxEvent> watch({String? key}) {
    return _box?.watch(key: key) ?? const Stream.empty();
  }
}