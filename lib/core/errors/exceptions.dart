/// 应用异常基类
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// 网络异常
class NetworkException extends AppException {
  const NetworkException({
    super.message = '网络连接失败',
    super.code,
    super.originalError,
  });
}

/// 服务器异常
class ServerException extends AppException {
  final int? statusCode;

  const ServerException({
    super.message = '服务器错误',
    super.code,
    super.originalError,
    this.statusCode,
  });
}

/// 认证异常
class AuthException extends AppException {
  const AuthException({
    super.message = '认证失败',
    super.code,
    super.originalError,
  });
}

/// 缓存异常
class CacheException extends AppException {
  const CacheException({
    super.message = '缓存读取失败',
    super.code,
    super.originalError,
  });
}

/// 蓝牙异常
class BluetoothException extends AppException {
  const BluetoothException({
    super.message = '蓝牙操作失败',
    super.code,
    super.originalError,
  });
}

/// MQTT异常
class MqttException extends AppException {
  const MqttException({
    super.message = 'MQTT连接失败',
    super.code,
    super.originalError,
  });
}

/// 权限异常
class PermissionException extends AppException {
  const PermissionException({
    super.message = '权限未授权',
    super.code,
    super.originalError,
  });
}

/// 数据解析异常
class ParseException extends AppException {
  const ParseException({
    super.message = '数据解析失败',
    super.code,
    super.originalError,
  });
}

/// 业务逻辑异常
class BusinessException extends AppException {
  const BusinessException({
    required super.message,
    super.code,
    super.originalError,
  });
}