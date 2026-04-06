import '../constants/app_constants.dart';
import '../constants/env_constants.dart';

/// API 客户端配置。
class ApiClientConfig {
  const ApiClientConfig({
    required this.baseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.sendTimeout,
    this.defaultHeaders = const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  });

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final Map<String, String> defaultHeaders;

  factory ApiClientConfig.fromEnv() {
    return ApiClientConfig(
      baseUrl: EnvConstants.apiBaseUrl,
      connectTimeout: AppConstants.connectionTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      sendTimeout: AppConstants.sendTimeout,
    );
  }
}
