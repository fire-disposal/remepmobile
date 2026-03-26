/// 失败结果封装
sealed class Failure {
  const Failure({required this.message});

  final String message;
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, this.statusCode});

  final int? statusCode;
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

class BluetoothFailure extends Failure {
  const BluetoothFailure({required super.message});
}

class MqttFailure extends Failure {
  const MqttFailure({required super.message});
}

class PermissionFailure extends Failure {
  const PermissionFailure({required super.message});
}

class BusinessFailure extends Failure {
  const BusinessFailure({required super.message, this.code});

  final String? code;
}

class UnknownFailure extends Failure {
  const UnknownFailure({required super.message});
}