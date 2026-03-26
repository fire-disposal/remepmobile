import 'package:permission_handler/permission_handler.dart';

/// 权限状态
enum AppPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  provisional,
}

/// 权限类型
enum AppPermission {
  camera,
  microphone,
  storage,
  location,
  bluetooth,
  notification,
}

/// 权限服务
/// 统一管理应用权限请求和检查
class PermissionService {
  /// 检查单个权限状态
  Future<AppPermissionStatus> checkPermission(AppPermission permission) async {
    final permissionHandler = _mapPermission(permission);
    final status = await permissionHandler.status;
    return _mapStatus(status);
  }

  /// 请求单个权限
  Future<AppPermissionStatus> requestPermission(AppPermission permission) async {
    final permissionHandler = _mapPermission(permission);
    final status = await permissionHandler.request();
    return _mapStatus(status);
  }

  /// 检查多个权限状态
  Future<Map<AppPermission, AppPermissionStatus>> checkPermissions(
    List<AppPermission> permissions,
  ) async {
    final result = <AppPermission, AppPermissionStatus>{};
    for (final permission in permissions) {
      result[permission] = await checkPermission(permission);
    }
    return result;
  }

  /// 请求多个权限
  Future<Map<AppPermission, AppPermissionStatus>> requestPermissions(
    List<AppPermission> permissions,
  ) async {
    final result = <AppPermission, AppPermissionStatus>{};
    for (final permission in permissions) {
      result[permission] = await requestPermission(permission);
    }
    return result;
  }

  /// 检查权限是否已授予
  Future<bool> isGranted(AppPermission permission) async {
    final status = await checkPermission(permission);
    return status == AppPermissionStatus.granted;
  }

  /// 检查权限是否被永久拒绝
  Future<bool> isPermanentlyDenied(AppPermission permission) async {
    final status = await checkPermission(permission);
    return status == AppPermissionStatus.permanentlyDenied;
  }

  /// 打开应用设置页面
  Future<bool> openSettings() async {
    return openAppSettings();
  }

  /// 请求摄像头权限
  Future<AppPermissionStatus> requestCameraPermission() async {
    final currentStatus = await checkPermission(AppPermission.camera);
    if (currentStatus == AppPermissionStatus.granted) {
      return currentStatus;
    }
    return requestPermission(AppPermission.camera);
  }

  /// 请求跌倒检测所需的所有权限
  Future<Map<AppPermission, AppPermissionStatus>> requestFallDetectionPermissions() async {
    return requestPermissions([
      AppPermission.camera,
    ]);
  }

  /// 检查跌倒检测权限是否全部授予
  Future<bool> checkFallDetectionPermissions() async {
    final cameraGranted = await isGranted(AppPermission.camera);
    return cameraGranted;
  }

  Permission _mapPermission(AppPermission permission) {
    switch (permission) {
      case AppPermission.camera:
        return Permission.camera;
      case AppPermission.microphone:
        return Permission.microphone;
      case AppPermission.storage:
        return Permission.storage;
      case AppPermission.location:
        return Permission.location;
      case AppPermission.bluetooth:
        return Permission.bluetooth;
      case AppPermission.notification:
        return Permission.notification;
    }
  }

  AppPermissionStatus _mapStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return AppPermissionStatus.granted;
      case PermissionStatus.denied:
        return AppPermissionStatus.denied;
      case PermissionStatus.permanentlyDenied:
        return AppPermissionStatus.permanentlyDenied;
      case PermissionStatus.restricted:
        return AppPermissionStatus.restricted;
      case PermissionStatus.limited:
        return AppPermissionStatus.limited;
      case PermissionStatus.provisional:
        return AppPermissionStatus.provisional;
    }
    // switch is exhaustive for known PermissionStatus values; no-op fallback
  }
}