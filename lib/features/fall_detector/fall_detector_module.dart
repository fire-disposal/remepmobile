import 'package:flutter_modular/flutter_modular.dart';

import 'data/services/fall_detector_service.dart';
import 'presentation/controllers/fall_detector_controller.dart';
import 'presentation/pages/fall_detector_page.dart';

/// 跌倒检测模拟器模块
class FallDetectorModule extends Module {
  @override
  void binds(Injector i) {
    // 数据层 - 服务
    i.addLazySingleton<FallDetectorService>(FallDetectorService.new);

    // 应用层 - 控制器
    i.addLazySingleton<FallDetectorController>(FallDetectorController.new);
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (context) => const FallDetectorPage());
  }
}