import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../auth/auth_token_provider.dart';
import 'api_client_config.dart';
import 'api_request_auth.dart';
import '../constants/env_constants.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';

/// Dio 客户端
class DioClient {
  late final Dio _dio;

  DioClient({
    ApiClientConfig? config,
    AuthTokenProvider? tokenProvider,
  }) {
    final resolvedConfig = config ?? ApiClientConfig.fromEnv();

    _dio = Dio(
      BaseOptions(
        baseUrl: resolvedConfig.baseUrl,
        connectTimeout: resolvedConfig.connectTimeout,
        receiveTimeout: resolvedConfig.receiveTimeout,
        sendTimeout: resolvedConfig.sendTimeout,
        headers: resolvedConfig.defaultHeaders,
      ),
    );

    // 添加拦截器
    _dio.interceptors.addAll([
      AuthInterceptor(tokenProvider: tokenProvider),
      ErrorInterceptor(),
      if (EnvConstants.debugMode)
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 90,
        ),
    ]);
  }

  /// 获取 Dio 实例
  Dio get dio => _dio;

  /// GET 请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool requireAuth = false,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: _resolveOptions(options, requireAuth: requireAuth),
      cancelToken: cancelToken,
    );
  }

  /// POST 请求
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool requireAuth = false,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _resolveOptions(options, requireAuth: requireAuth),
      cancelToken: cancelToken,
    );
  }

  /// PUT 请求
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool requireAuth = true,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _resolveOptions(options, requireAuth: requireAuth),
      cancelToken: cancelToken,
    );
  }

  /// DELETE 请求
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool requireAuth = true,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _resolveOptions(options, requireAuth: requireAuth),
      cancelToken: cancelToken,
    );
  }

  /// PATCH 请求
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool requireAuth = true,
  }) async {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _resolveOptions(options, requireAuth: requireAuth),
      cancelToken: cancelToken,
    );
  }

  /// 上传文件
  Future<Response<T>> upload<T>(
    String path, {
    required FormData data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    bool requireAuth = true,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      options: _resolveOptions(options, requireAuth: requireAuth),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }

  /// 下载文件
  Future<Response<dynamic>> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    bool requireAuth = true,
  }) async {
    return _dio.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: _resolveOptions(options, requireAuth: requireAuth),
    );
  }

  Options _resolveOptions(Options? options, {required bool requireAuth}) {
    final resolved = options ?? Options();
    return resolved.withAuth(requiredAuth: requireAuth);
  }
}
