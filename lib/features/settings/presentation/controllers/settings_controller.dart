import 'package:flutter/material.dart';

import '../../../../core/permission/permission_service.dart';
import '../../../../core/storage/cache_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/theme_notifier.dart';

/// 设置状态
class SettingsState {
  final AppThemeMode themeMode;
  final Map<AppPermission, AppPermissionStatus> permissions;
  final bool isLoading;

  const SettingsState({
    this.themeMode = AppThemeMode.system,
    this.permissions = const {},
    this.isLoading = false,
  });

  SettingsState copyWith({
    AppThemeMode? themeMode,
    Map<AppPermission, AppPermissionStatus>? permissions,
    bool? isLoading,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      permissions: permissions ?? this.permissions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 设置控制器
/// 
/// 管理应用设置，包括主题、权限等
/// 移除了模型管理相关功能（模型切换功能已删除）
class SettingsController extends ChangeNotifier {
  final ThemeModeNotifier _themeModeNotifier;
  final CacheStorageService _cacheStorage;
  final SecureStorageService _secureStorage;
  final PermissionService _permissionService;

  SettingsState _state = const SettingsState();
  SettingsState get state => _state;

  SettingsController(
    this._themeModeNotifier,
    this._cacheStorage,
    this._secureStorage,
    this._permissionService,
  ) {
    _init();
  }

  Future<void> _init() async {
    _state = _state.copyWith(
      themeMode: _themeModeNotifier.mode,
      isLoading: true,
    );
    notifyListeners();
    await refreshPermissions();
  }

  /// 刷新所有权限状态
  Future<void> refreshPermissions() async {
    final permissions = await _permissionService.checkPermissions(AppPermission.values);
    _state = _state.copyWith(
      permissions: permissions,
      isLoading: false,
    );
    notifyListeners();
  }

  /// 请求特定权限
  Future<void> requestPermission(AppPermission permission) async {
    await _permissionService.requestPermission(permission);
    await refreshPermissions();
  }

  /// 请求视觉识别模块依赖权限
  Future<void> requestVisionPermissions() async {
    await _permissionService.requestVisionDetectionPermissions();
    await refreshPermissions();
  }

  /// 请求IMU监测模块依赖权限
  Future<Map<AppPermission, AppPermissionStatus>> requestIMUPermissions() async {
    final result = await _permissionService.requestIMUPermissions();
    await refreshPermissions();
    return result;
  }

  /// 检查IMU权限状态
  Future<bool> checkIMUPermissions() async {
    return _permissionService.checkIMUPermissions();
  }

  /// 获取未授权的IMU权限
  Future<List<AppPermission>> getDeniedIMUPermissions() async {
    return _permissionService.getDeniedIMUPermissions();
  }

  /// 打开系统设置
  Future<void> openAppSettings() async {
    await _permissionService.openSettings();
  }

  /// 设置主题模式
  Future<void> setThemeMode(AppThemeMode mode) async {
    await _themeModeNotifier.setThemeMode(mode);
    _state = _state.copyWith(themeMode: mode);
    notifyListeners();
  }

  /// 清除本地存储
  Future<void> clearAllData() async {
    await _secureStorage.deleteAll();
    await _cacheStorage.deleteAll();
    _state = _state.copyWith(themeMode: AppThemeMode.system);
    notifyListeners();
  }

}
