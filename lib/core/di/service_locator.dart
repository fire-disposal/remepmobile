import 'package:get_it/get_it.dart';

import '../bluetooth/bluetooth_service.dart';
import '../mqtt/mqtt_service.dart';
import '../services/permission_service.dart';
import '../storage/cache_service.dart';
import '../theme/theme_notifier.dart';

final getIt = GetIt.instance;

/// 注册本地调试模式所需的基础设施层。
///
/// 当前应用不依赖远端后端、鉴权和拦截器，仅保留本地可用的
/// MQTT / 蓝牙 / 存储 / 权限基础能力，方便后续模块接入。
void setupServiceLocator() {
  getIt.registerSingleton<CacheStorageService>(CacheStorageService());
  getIt.registerSingleton<MqttService>(MqttService());
  getIt.registerSingleton<BluetoothService>(BluetoothService());
  getIt.registerSingleton<PermissionService>(PermissionService());
  getIt.registerSingleton<ThemeModeNotifier>(ThemeModeNotifier(getIt<CacheStorageService>()));
}
