import 'package:flutter_modular/flutter_modular.dart';

import '../../core/auth/session_service.dart';

class AuthGuard extends RouteGuard {
  AuthGuard() : super(redirectTo: '/login');

  @override
  Future<bool> canActivate(String path, ParallelRoute route) async {
    final session = Modular.get<SessionService>();
    await session.bootstrap();
    return session.isAuthenticated;
  }
}
