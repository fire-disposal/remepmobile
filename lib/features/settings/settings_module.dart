import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../core/permission/permission_service.dart';
import '../../core/storage/cache_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/theme/theme_notifier.dart';
import 'presentation/controllers/settings_controller.dart';
import 'presentation/page/settings_page.dart';

class SettingsModule {
  static void registerDependencies(GetIt getIt) {
    // 模块自包含依赖注册
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
