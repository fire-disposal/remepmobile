import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
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
  sensors, // 惯性传感器 (IMU)
  activityRecognition, // 活动识别 (步态检测)
}

/// 权限服务
/// 统一管理应用权限请求和检查
class PermissionService {
  static const List<AppPermission> visionDetectionRequiredPermissions = [
    AppPermission.camera,
  ];

  /// 检查单个权限状态
  Future<AppPermissionStatus> checkPermission(AppPermission permission) async {
    final permissionHandler = _mapPermission(permission);
    final status = await permissionHandler.status;
    return _mapStatus(status);
  }

  /// 请求单个权限
  /// 
  /// 对于蓝牙权限，在 Android 12+ 会自动请求 bluetoothScan 和 bluetoothConnect
  Future<AppPermissionStatus> requestPermission(AppPermission permission) async {
    // 蓝牙权限特殊处理：Android 12+ 需要同时请求 SCAN 和 CONNECT
    if (permission == AppPermission.bluetooth) {
      return requestBluetoothPermissions();
    }
    
    final permissionHandler = _mapPermission(permission);
    final status = await permissionHandler.request();
    return _mapStatus(status);
  }

  /// 请求蓝牙权限（Android 12+ 需要 SCAN 和 CONNECT）
  Future<AppPermissionStatus> requestBluetoothPermissions() async {
    // 请求蓝牙扫描权限
    final scanStatus = await Permission.bluetoothScan.request();
    
    // 请求蓝牙连接权限
    final connectStatus = await Permission.bluetoothConnect.request();
    
    // 如果任一权限被拒绝，返回 denied
    if (scanStatus.isDenied || connectStatus.isDenied) {
      return AppPermissionStatus.denied;
    }
    
    // 如果任一权限被永久拒绝，返回 permanentlyDenied
    if (scanStatus.isPermanentlyDenied || connectStatus.isPermanentlyDenied) {
      return AppPermissionStatus.permanentlyDenied;
    }
    
    // 都授予了
    if (scanStatus.isGranted && connectStatus.isGranted) {
      return AppPermissionStatus.granted;
    }
    
    // 其他情况
    return _mapStatus(scanStatus);
  }

  /// 检查多个权限状态
  Future<Map<AppPermission, AppPermissionStatus>> checkPermissions(
    List<AppPermission> permissions,
  ) async {
    final result = <AppPermission, AppPermissionStatus>{};
    for (final permission in permissions) {
      // 跳过在当前平台不可用的权限
      if (!await _isPermissionAvailable(permission)) {
        result[permission] = AppPermissionStatus.granted;
        continue;
      }
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
      // 跳过在当前平台不可用的权限
      if (!await _isPermissionAvailable(permission)) {
        result[permission] = AppPermissionStatus.granted;
        continue;
      }
      result[permission] = await requestPermission(permission);
    }
    return result;
  }

  /// 检查权限是否已授予
  Future<bool> isGranted(AppPermission permission) async {
    // 如果权限在当前平台不可用，视为已授权
    if (!await _isPermissionAvailable(permission)) {
      return true;
    }
    final status = await checkPermission(permission);
    return status == AppPermissionStatus.granted;
  }

  /// 检查权限在当前平台是否可用
  Future<bool> _isPermissionAvailable(AppPermission permission) async {
    if (!Platform.isAndroid) {
      // iOS 上 sensors 和 activityRecognition 通常不需要单独请求
      return false;
    }
    
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    
    switch (permission) {
      case AppPermission.activityRecognition:
        // ACTIVITY_RECOGNITION 只在 Android 10+ (API 29+) 可用
        return sdkInt >= 29;
      case AppPermission.sensors:
        // Android 13+ (API 33+) 使用 BODY_SENSORS 替代
        // 但 Flutter permission_handler 已内部处理
        return true;
      case AppPermission.notification:
        // 通知权限只在 Android 13+ (API 33+) 需要动态请求
        return sdkInt >= 33;
      default:
        return true;
    }
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
    return requestPermissions(visionDetectionRequiredPermissions);
  }

  /// 检查跌倒检测权限是否全部授予
  Future<bool> checkFallDetectionPermissions() async {
    final statuses = await checkPermissions(visionDetectionRequiredPermissions);
    return statuses.values.every((status) => status == AppPermissionStatus.granted);
  }

  /// 请求视觉识别实验台所需权限
  Future<Map<AppPermission, AppPermissionStatus>> requestVisionDetectionPermissions() async {
    return requestPermissions(visionDetectionRequiredPermissions);
  }

  /// 检查视觉识别实验台权限是否全部授予
  Future<bool> checkVisionDetectionPermissions() async {
    final statuses = await checkPermissions(visionDetectionRequiredPermissions);
    return statuses.values.every((status) => status == AppPermissionStatus.granted);
  }

  /// IMU监测所需的权限组
  /// 注意：根据 Android 版本不同，实际请求的权限有所差异
  static const List<AppPermission> imuMonitoringRequiredPermissions = [
    AppPermission.sensors,
    AppPermission.activityRecognition,
  ];

  /// 通知权限 - Android 13+ (API 33+)
  static const List<AppPermission> notificationPermissions = [
    AppPermission.notification,
  ];

  /// 请求IMU监测所需权限
  Future<Map<AppPermission, AppPermissionStatus>> requestIMUPermissions() async {
    final result = <AppPermission, AppPermissionStatus>{};
    for (final permission in imuMonitoringRequiredPermissions) {
      // 跳过在当前平台不可用的权限
      if (!await _isPermissionAvailable(permission)) {
        result[permission] = AppPermissionStatus.granted;
        continue;
      }
      result[permission] = await requestPermission(permission);
    }
    return result;
  }

  /// 检查IMU监测权限是否全部授予
  Future<bool> checkIMUPermissions() async {
    for (final permission in imuMonitoringRequiredPermissions) {
      // 跳过在当前平台不可用的权限
      if (!await _isPermissionAvailable(permission)) {
        continue;
      }
      final status = await checkPermission(permission);
      if (status != AppPermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  /// 获取未授权的IMU权限列表
  Future<List<AppPermission>> getDeniedIMUPermissions() async {
    final denied = <AppPermission>[];
    for (final permission in imuMonitoringRequiredPermissions) {
      // 跳过在当前平台不可用的权限
      if (!await _isPermissionAvailable(permission)) {
        continue;
      }
      final status = await checkPermission(permission);
      if (status != AppPermissionStatus.granted) {
        denied.add(permission);
      }
    }
    return denied;
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
        // Android 12+ (API 31+) 使用新的蓝牙权限
        // 优先返回 bluetoothScan，如果不支持则回退到 bluetooth
        return Permission.bluetoothScan;
      case AppPermission.notification:
        return Permission.notification;
      case AppPermission.sensors:
        return Permission.sensors;
      case AppPermission.activityRecognition:
        // Android 10+ (API 29+) 需要 ACTIVITY_RECOGNITION 权限
        // 低版本系统此权限不存在，直接返回 sensors 作为替代
        return Permission.activityRecognition;
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
