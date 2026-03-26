import 'package:flutter/material.dart';

import '../storage/cache_service.dart';
import '../constants/app_constants.dart';
import 'app_theme.dart';

/// 主题模式
enum AppThemeMode {
  system,
  light,
  dark,
}

/// 主题模式状态管理
class ThemeModeNotifier extends ChangeNotifier {
  final CacheStorageService _cacheStorage;

  AppThemeMode _mode = AppThemeMode.system;
  AppThemeMode get mode => _mode;

  ThemeModeNotifier(this._cacheStorage) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final savedMode = _cacheStorage.read<String>(AppConstants.themeKey);
    if (savedMode != null) {
      _mode = AppThemeMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => AppThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _mode = mode;
    await _cacheStorage.write(AppConstants.themeKey, mode.name);
    notifyListeners();
  }

  /// 获取 Flutter ThemeMode
  ThemeMode get flutterThemeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

/// 获取主题数据
ThemeData getThemeData(AppThemeMode mode, Brightness brightness) {
  switch (mode) {
    case AppThemeMode.light:
      return AppTheme.lightTheme;
    case AppThemeMode.dark:
      return AppTheme.darkTheme;
    case AppThemeMode.system:
      return brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  }
}