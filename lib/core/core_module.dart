import 'package:flutter_modular/flutter_modular.dart';

import '../features/fall_detector/data/services/fall_detector_service.dart';
import '../features/fall_detector/data/services/model_manager_service.dart';
import '../features/fall_detector/presentation/controllers/fall_detector_controller.dart';
import '../features/mqtt_debug/data/services/mqtt_debug_service.dart';
import '../features/mqtt_debug/presentation/controllers/mqtt_debug_controller.dart';
import '../features/settings/presentation/controllers/settings_controller.dart';
import 'api/api_module.dart';
import 'auth/session_service.dart';
import 'bluetooth/bluetooth_service.dart';
import 'mqtt/mqtt_service.dart';
import 'services/permission_service.dart';
import 'storage/cache_service.dart';
import 'storage/secure_storage_service.dart';
import 'theme/theme_notifier.dart';

/// 核心模块
/// 统一管理基础设施和业务控制器，避免按功能再拆大量 Module。
class CoreModule extends Module {
  @override
  List<Module> get imports => [ApiModule()];

  @override
  void binds(Injector i) {
    i.addSingleton<CacheStorageService>(CacheStorageService.new);
    i.addSingleton<SecureStorageService>(SecureStorageService.new);
    i.addSingleton<SessionService>(SessionService.new);

    i.addSingleton<MqttService>(MqttService.new);
    i.addSingleton<BluetoothService>(BluetoothService.new);
    i.addSingleton<PermissionService>(PermissionService.new);
    i.addSingleton<ThemeModeNotifier>(ThemeModeNotifier.new);

    // 业务依赖统一注册，减少多模块并行开发时的 DI 跳转成本。
    i.addLazySingleton<MqttDebugService>(MqttDebugService.new);
    i.addLazySingleton<MqttDebugController>(MqttDebugController.new);
    i.addLazySingleton<FallDetectorService>(FallDetectorService.new);
    i.addLazySingleton<ModelManagerService>(ModelManagerService.new);
    i.addLazySingleton<FallDetectorController>(
      () => FallDetectorController(
        i.get<FallDetectorService>(),
        i.get<MqttService>(),
        i.get<PermissionService>(),
        i.get<ModelManagerService>(),
      ),
    );
    i.addLazySingleton<SettingsController>(SettingsController.new);
  }
}
