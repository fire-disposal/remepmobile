import 'package:flutter_modular/flutter_modular.dart';

import 'app_sections.dart';
import 'core/core_module.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/fall_detector/presentation/pages/fall_detector_page.dart';
import 'features/mqtt_debug/presentation/pages/mqtt_debug_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'pages/app_shell_page.dart';
import 'pages/guards/auth_guard.dart';
import 'pages/home/dashboard_page.dart';
import 'pages/launch_page.dart';

class AppModule extends Module {
  @override
  List<Module> get imports => [CoreModule()];

  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const LaunchPage());
    r.child('/login', child: (_) => const LoginPage());

    r.child(
      '/app',
      guards: [AuthGuard()],
      child: (_) => const AppShellPage(),
      children: [
        ChildRoute(appSections[0].childPath, child: (_) => const FallDetectorPage()),
        ChildRoute(appSections[1].childPath, child: (_) => const MqttDebugPage()),
        ChildRoute(appSections[2].childPath, child: (_) => const DashboardPage()),
        ChildRoute(appSections[3].childPath, child: (_) => const SettingsPage()),
      ],
    );
  }
}
