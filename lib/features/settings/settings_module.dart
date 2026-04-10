import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/permission/permission_service.dart';
import '../../core/storage/cache_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/theme/theme_notifier.dart';
import 'presentation/controllers/settings_controller.dart';
import 'presentation/page/settings_page.dart';

/// 设置模块
/// 
/// 管理应用设置，包括主题、权限等
/// 注意：模型管理功能已移除（使用固定 YOLO 模型）
class SettingsModule {
  static void registerDependencies(GetIt getIt) {
    getIt.registerLazySingleton<SettingsController>(() => SettingsController(
      getIt<ThemeModeNotifier>(),
      getIt<CacheStorageService>(),
      getIt<SecureStorageService>(),
      getIt<PermissionService>(),
    ));
  }

  static List<RouteBase> get routes => [
    GoRoute(
      path: '/app/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ];
}
