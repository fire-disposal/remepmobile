import 'package:flutter_modular/flutter_modular.dart';

import 'data/services/mqtt_debug_service.dart';
import 'presentation/controllers/mqtt_debug_controller.dart';
import 'presentation/pages/mqtt_debug_page.dart';

/// MQTT 调试模块
class MqttDebugModule extends Module {
  @override
  void binds(Injector i) {
    // 数据层 - 服务
    i.addLazySingleton<MqttDebugService>(MqttDebugService.new);

    // 应用层 - 控制器
    i.addLazySingleton<MqttDebugController>(MqttDebugController.new);
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (context) => const MqttDebugPage());
  }
}