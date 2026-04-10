import 'package:get_it/get_it.dart';
import '../../features/settings/settings_module.dart';
import '../../features/bluetooth_scanner/bluetooth_scanner_module.dart';
import '../events/global_event_store.dart';
import '../mqtt/mqtt_config_service.dart';
import '../../features/vision_detection/vision_detection_controller.dart';
import '../../features/imu_monitoring/imu_sensor_service.dart';
import '../bluetooth/bluetooth_service.dart';
import '../mqtt/mqtt_service.dart';
import '../permission/permission_service.dart';
import '../storage/cache_service.dart';
import '../storage/secure_storage_service.dart';
import '../theme/theme_notifier.dart';

final getIt = GetIt.instance;

/// 异步初始化核心基础设施，确保线程安全且不阻塞 UI 绘制。
Future<void> setupServiceLocator() async {
  // 1. 注册基础存储服务（需优先初始化）
  final cacheService = CacheStorageService();
  await cacheService.init();
  getIt.registerSingleton<CacheStorageService>(cacheService);

  // 1.1 注册安全存储服务
  getIt.registerSingleton<SecureStorageService>(SecureStorageService());
  getIt.registerSingleton<GlobalEventStore>(GlobalEventStore());

  // 2. 注册其他异步或长耗时服务
  getIt.registerLazySingleton<MqttService>(() => MqttService());
  getIt.registerLazySingleton<MqttConfigService>(
    () => MqttConfigService(
      getIt<CacheStorageService>(),
      getIt<MqttService>(),
    ),
  );
  getIt.registerLazySingleton<PermissionService>(() => PermissionService());
  getIt.registerLazySingleton<BluetoothService>(() => BluetoothService());
  getIt.registerLazySingleton<IMUSensorService>(() => IMUSensorService());
  getIt.registerLazySingleton<VisionDetectionController>(
    () => VisionDetectionController(
      mqttConfigService: getIt<MqttConfigService>(),
      eventStore: getIt<GlobalEventStore>(),
      permissionService: getIt<PermissionService>(),
    ),
  );
  
  // 3. 注册依赖于存储的状态通知器
  getIt.registerSingleton<ThemeModeNotifier>(ThemeModeNotifier(getIt<CacheStorageService>()));
  
  // 4. 注册业务功能模块的依赖项 (Feature DI)
  SettingsModule.registerDependencies(getIt);
  BluetoothScannerModule.registerDependencies(getIt);

  await getIt<MqttConfigService>().initialize();
  
  // 等待所有异步单例就绪（如果有使用 registerSingletonAsync）
  await getIt.allReady();
}
