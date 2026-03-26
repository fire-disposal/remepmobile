import 'package:flutter_modular/flutter_modular.dart';

import 'presentation/controllers/settings_controller.dart';
import 'presentation/pages/settings_page.dart';

/// 设置模块
class SettingsModule extends Module {
  @override
  void binds(Injector i) {
    // 应用层 - 控制器
    i.addLazySingleton<SettingsController>(SettingsController.new);
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (context) => const SettingsPage());
  }
}