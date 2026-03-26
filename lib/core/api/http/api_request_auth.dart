import 'package:dio/dio.dart';

/// 通过 request.extra 声明接口是否需要鉴权。
abstract final class ApiRequestAuth {
  static const String key = 'require_auth';
}

extension ApiRequestOptionsX on Options {
  /// 标记当前请求是否要求携带登录态 token。
  Options withAuth({required bool requiredAuth}) {
    final nextExtra = <String, dynamic>{...?extra};
    nextExtra[ApiRequestAuth.key] = requiredAuth;

    return copyWith(extra: nextExtra);
  }
}
