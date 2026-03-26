import 'package:flutter_modular/flutter_modular.dart';

import 'presentation/pages/login_page.dart';

/// 认证模块
class AuthModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child('/', child: (context) => const LoginPage());
  }
}