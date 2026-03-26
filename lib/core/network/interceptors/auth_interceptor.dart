import 'package:dio/dio.dart';

import '../../constants/app_constants.dart';
import '../../storage/secure_storage_service.dart';

/// 认证拦截器
class AuthInterceptor extends Interceptor {
  final SecureStorageService _secureStorage;

  AuthInterceptor({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? SecureStorageService();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // 排除不需要认证的接口
    final excludedPaths = [
      '/auth/login',
      '/auth/register',
      '/auth/forgot-password',
      '/auth/reset-password',
    ];

    if (excludedPaths.any((path) => options.path.contains(path))) {
      return handler.next(options);
    }

    // 添加认证Token
    final token = await _secureStorage.read(key: AppConstants.tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Token过期处理
    if (err.response?.statusCode == 401) {
      // TODO: 实现Token刷新逻辑
      // 可以在这里调用刷新Token的接口
    }

    return handler.next(err);
  }
}