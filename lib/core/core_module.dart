import 'package:flutter_modular/flutter_modular.dart';

import 'api/api_module.dart';
import 'bluetooth/bluetooth_service.dart';
import 'mqtt/mqtt_service.dart';
import 'services/permission_service.dart';
import 'storage/cache_service.dart';
import 'storage/secure_storage_service.dart';

/// 核心模块
/// 提供全局服务：网络、存储、MQTT、蓝牙、权限等
class CoreModule extends Module {
  @override
  List<Module> get imports => [ApiModule()];

  @override
  void binds(Injector i) {
    // 存储服务
    i.addSingleton<CacheStorageService>(CacheStorageService.new);
    i.addSingleton<SecureStorageService>(SecureStorageService.new);


    // MQTT 服务
    i.addSingleton<MqttService>(MqttService.new);

    // 蓝牙服务
    i.addSingleton<BluetoothService>(BluetoothService.new);

    // 权限服务
    i.addSingleton<PermissionService>(PermissionService.new);

    // ⚠️ API 客户端已暂时禁用 - 待 retrofit/Dio 客户端问题解决后启用
    // i.addSingleton<AuthClient>((_) => AuthClient(i.get()));
    // i.addSingleton<UsersClient>((_) => UsersClient(i.get()));
    // i.addSingleton<PatientsClient>((_) => PatientsClient(i.get()));
    // i.addSingleton<DevicesClient>((_) => DevicesClient(i.get()));
    // i.addSingleton<BindingsClient>((_) => BindingsClient(i.get()));
    // i.addSingleton<DataClient>((_) => DataClient(i.get()));
  }
}