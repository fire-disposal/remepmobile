import 'package:get_it/get_it.dart';

import '../api/config/api_client_config.dart';
import '../network/dio_client.dart';
import '../auth/session_service.dart';
import '../bluetooth/bluetooth_service.dart';
import '../mqtt/mqtt_service.dart';
import '../services/permission_service.dart';
import '../storage/cache_service.dart';
import '../storage/secure_storage_service.dart';
import '../theme/theme_notifier.dart';
import '../../features/fall_detector/data/services/fall_detector_service.dart';
import '../../features/fall_detector/data/services/model_manager_service.dart';
import '../../features/fall_detector/presentation/controllers/fall_detector_controller.dart';
import '../../features/mqtt_debug/data/services/mqtt_debug_service.dart';
import '../../features/mqtt_debug/presentation/controllers/mqtt_debug_controller.dart';
import '../../features/settings/presentation/controllers/settings_controller.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // API & Network
  getIt.registerSingleton<ApiClientConfig>(ApiClientConfig.fromEnv());
  getIt.registerSingleton<DioClient>(
    DioClient(config: getIt<ApiClientConfig>()),
  );

  // Core infrastructure
  getIt.registerSingleton<CacheStorageService>(CacheStorageService());
  getIt.registerSingleton<SecureStorageService>(SecureStorageService());
  getIt.registerSingleton<SessionService>(SessionService(getIt<SecureStorageService>()));
  getIt.registerSingleton<MqttService>(MqttService());
  getIt.registerSingleton<BluetoothService>(BluetoothService());
  getIt.registerSingleton<PermissionService>(PermissionService());
  getIt.registerSingleton<ThemeModeNotifier>(ThemeModeNotifier(getIt<CacheStorageService>()));

  // Feature services
  getIt.registerLazySingleton<MqttDebugService>(
    () => MqttDebugService(getIt<MqttService>()),
  );
  getIt.registerLazySingleton<FallDetectorService>(
    () => FallDetectorService(getIt<MqttService>()),
  );
  getIt.registerLazySingleton<ModelManagerService>(ModelManagerService.new);

  // Controllers
  getIt.registerLazySingleton<MqttDebugController>(
    () => MqttDebugController(
      getIt<MqttDebugService>(),
      getIt<CacheStorageService>(),
    ),
  );

  getIt.registerLazySingleton<FallDetectorController>(
    () => FallDetectorController(
      getIt<FallDetectorService>(),
      getIt<MqttService>(),
      getIt<PermissionService>(),
      getIt<ModelManagerService>(),
    ),
  );

  getIt.registerLazySingleton<SettingsController>(
    () => SettingsController(
      getIt<ThemeModeNotifier>(),
      getIt<CacheStorageService>(),
      getIt<SecureStorageService>(),
    ),
  );
}
