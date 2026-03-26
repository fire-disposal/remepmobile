/// 应用常量定义
class AppConstants {
  AppConstants._();

  // 应用信息
  static const String appName = 'ReMep Mobile';
  static const String appVersion = '1.0.0';

  // 存储键
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String localeKey = 'locale';

  // 超时配置
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // 缓存配置
  static const Duration cacheValidDuration = Duration(hours: 1);
  static const int maxCacheSize = 100;

  // 分页配置
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
}

/// API端点定义
class ApiEndpoints {
  ApiEndpoints._();

  // 认证相关
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // 用户相关
  static const String profile = '/user/profile';
  static const String updateProfile = '/user/profile/update';

  // 设备相关
  static const String devices = '/devices';
  static const String deviceConnect = '/devices/connect';
  static const String deviceDisconnect = '/devices/disconnect';

  // 健康数据
  static const String healthData = '/health/data';
  static const String healthStats = '/health/stats';
}

/// MQTT主题定义
class MqttTopics {
  MqttTopics._();

  static const String baseTopic = 'remep';

  // 设备相关
  static String deviceStatus(String deviceId) => '$baseTopic/device/$deviceId/status';
  static String deviceData(String deviceId) => '$baseTopic/device/$deviceId/data';

  // 用户相关
  static String userAlerts(String userId) => '$baseTopic/user/$userId/alerts';
  static String userNotifications(String userId) => '$baseTopic/user/$userId/notifications';
}