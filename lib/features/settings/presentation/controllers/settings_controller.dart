import 'package:flutter/material.dart';

import '../../../../core/storage/cache_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/theme_notifier.dart';

/// 设置状态
class SettingsState {
  final bool isNotificationEnabled;
  final bool isEmailNotificationEnabled;
  final AppThemeMode themeMode;
  final String? userName;
  final String? userEmail;

  const SettingsState({
    this.isNotificationEnabled = true,
    this.isEmailNotificationEnabled = false,
    this.themeMode = AppThemeMode.system,
    this.userName,
    this.userEmail,
  });

  SettingsState copyWith({
    bool? isNotificationEnabled,
    bool? isEmailNotificationEnabled,
    AppThemeMode? themeMode,
    String? userName,
    String? userEmail,
  }) {
    return SettingsState(
      isNotificationEnabled: isNotificationEnabled ?? this.isNotificationEnabled,
      isEmailNotificationEnabled: isEmailNotificationEnabled ?? this.isEmailNotificationEnabled,
      themeMode: themeMode ?? this.themeMode,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
    );
  }
}

/// 设置控制器
class SettingsController extends ChangeNotifier {
  final ThemeModeNotifier _themeModeNotifier;
  final CacheStorageService _cacheStorage;
  final SecureStorageService _secureStorage;

  SettingsState _state = const SettingsState();
  SettingsState get state => _state;

  SettingsController(
    this._themeModeNotifier,
    this._cacheStorage,
    this._secureStorage,
  ) {
    _init();
  }

  void _init() {
    _state = _state.copyWith(
      themeMode: _themeModeNotifier.mode,
    );
  }

  /// 设置主题模式
  Future<void> setThemeMode(AppThemeMode mode) async {
    await _themeModeNotifier.setThemeMode(mode);
    _state = _state.copyWith(themeMode: mode);
    notifyListeners();
  }

  /// 切换通知开关
  void toggleNotification(bool value) {
    _state = _state.copyWith(isNotificationEnabled: value);
    notifyListeners();
  }

  /// 切换邮件通知开关
  void toggleEmailNotification(bool value) {
    _state = _state.copyWith(isEmailNotificationEnabled: value);
    notifyListeners();
  }

  /// 退出登录
  Future<void> logout() async {
    await _secureStorage.deleteAll();
    await _cacheStorage.deleteAll();
    _state = const SettingsState();
    notifyListeners();
  }

  /// 清除缓存
  Future<void> clearCache() async {
    await _cacheStorage.deleteAll();
  }
}