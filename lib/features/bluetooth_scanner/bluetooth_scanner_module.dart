import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../core/bluetooth/bluetooth_service.dart';
import 'bluetooth_scanner_controller.dart';
import 'bluetooth_scanner_page.dart';

/// 蓝牙扫描模块
/// 提供 BLE 设备扫描、发现和连接功能
class BluetoothScannerModule {
  static void registerDependencies(GetIt getIt) {
    // 模块自包含依赖注册
    getIt.registerFactory<BluetoothScannerController>(
      () => BluetoothScannerController(
        bluetoothService: getIt<BluetoothService>(),
      ),
    );
  }

  static List<RouteBase> get routes => [
    GoRoute(
      path: '/app/bluetooth/scanner',
      builder: (context, state) => const BluetoothScannerPage(),
    ),
  ];
}
