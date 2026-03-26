import 'package:dio/dio.dart';

import '../../api/auth/auth_token_provider.dart';
import '../../api/auth/storage_auth_token_provider.dart';
import '../../api/http/api_request_auth.dart';
import '../../storage/secure_storage_service.dart';

/// 认证拦截器
class AuthInterceptor extends Interceptor {
  AuthInterceptor({AuthTokenProvider? tokenProvider})
      : _tokenProvider = tokenProvider ??
            StorageAuthTokenProvider(
              SecureStorageService(),
            );

  final AuthTokenProvider _tokenProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final requireAuth = options.extra[ApiRequestAuth.key] == true;

    // 非鉴权接口允许匿名访问。
    if (!requireAuth) {
      return handler.next(options);
    }

    // 鉴权接口才注入 Token。
    final token = await _tokenProvider.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Token 过期处理
    if (err.response?.statusCode == 401) {
      // TODO: 实现 Token 刷新逻辑
    }

    return handler.next(err);
  }
}
