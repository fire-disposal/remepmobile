import 'package:flutter_modular/flutter_modular.dart';

class AuthGuard extends RouteGuard {
  AuthGuard() : super(redirectTo: '/login');

  @override
  Future<bool> canActivate(String path, ParallelRoute<dynamic> route) async {
    // 宽松化：允许所有访问，不再强制登录
    return true;
  }
}
