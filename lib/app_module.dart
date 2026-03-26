import 'package:flutter_modular/flutter_modular.dart';

import 'core/core_module.dart';
import 'features/auth/auth_module.dart';
import 'features/mqtt_debug/mqtt_debug_module.dart';
import 'features/fall_detector/fall_detector_module.dart';
import 'features/settings/settings_module.dart';
// ⚠️ FallDetection 模块已暂时禁用 - 待 TFLite 和 Camera 权限问题解决后启用
// import 'features/fall_detection/fall_detection_module.dart';
import 'pages/app_shell_page.dart';

/// 应用主模块
class AppModule extends Module {
  @override
  List<Module> get imports => [CoreModule()];

  @override
  void binds(Injector i) {
    // 应用级别的绑定
  }

  @override
  void routes(RouteManager r) {
    // 主应用 Shell
    r.child('/', child: (context) => const AppShellPage());

    // 功能模块
    r.module('/auth', module: AuthModule());
    r.module('/mqtt-debug', module: MqttDebugModule());
    r.module('/fall-detector', module: FallDetectorModule());
    r.module('/settings', module: SettingsModule());
    
    // ⚠️ FallDetection 模块路由已暂时禁用
    // r.module('/fall-detection', module: FallDetectionModule());
  }
}