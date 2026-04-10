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
}

/// 权限服务
/// 统一管理应用权限请求和检查
class PermissionService {
  static const List<AppPermission> visionDetectionRequiredPermissions = [
    AppPermission.camera,
  ];

  Future<int?> _androidSdkInt() async {
    if (!Platform.isAndroid) return null;
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt;
  }

  /// 检查单个权限状态
  Future<AppPermissionStatus> checkPermission(AppPermission permission) async {
    if (!await _isPermissionAvailable(permission)) {
      return AppPermissionStatus.granted;
    }

    if (permission == AppPermission.bluetooth) {
      return _checkBluetoothPermissionStatus();
    }

    if (permission == AppPermission.storage) {
      return _checkStoragePermissionStatus();
    }

    final permissionHandler = _mapPermission(permission);
    final status = await permissionHandler.status;
    return _mapStatus(status);
  }

  /// 请求单个权限
  /// 
  /// 对于蓝牙权限，在 Android 12+ 会自动请求 bluetoothScan 和 bluetoothConnect
  Future<AppPermissionStatus> requestPermission(AppPermission permission) async {
    if (!await _isPermissionAvailable(permission)) {
      return AppPermissionStatus.granted;
    }

    // 蓝牙权限特殊处理：Android 12+ 需要同时请求 SCAN 和 CONNECT
    if (permission == AppPermission.bluetooth) {
      return requestBluetoothPermissions();
    }

    // 文件访问权限在高版本 Android 需要走分版本策略
    if (permission == AppPermission.storage) {
      return requestStoragePermissions();
    }
    
    final permissionHandler = _mapPermission(permission);
    final status = await permissionHandler.request();
    return _mapStatus(status);
  }

  Future<AppPermissionStatus> _checkBluetoothPermissionStatus() async {
    if (!Platform.isAndroid) {
      return _mapStatus(await Permission.bluetooth.status);
    }

    final sdkInt = await _androidSdkInt() ?? 0;
    if (sdkInt < 31) {
      return _mapStatus(await Permission.bluetooth.status);
    }

    final scanStatus = await Permission.bluetoothScan.status;
    final connectStatus = await Permission.bluetoothConnect.status;
    if (scanStatus.isPermanentlyDenied || connectStatus.isPermanentlyDenied) {
      return AppPermissionStatus.permanentlyDenied;
    }
    if (scanStatus.isDenied || connectStatus.isDenied) {
      return AppPermissionStatus.denied;
    }
    if (scanStatus.isGranted && connectStatus.isGranted) {
      return AppPermissionStatus.granted;
    }
    return _mapStatus(scanStatus);
  }

  Future<AppPermissionStatus> _checkStoragePermissionStatus() async {
    if (!Platform.isAndroid) {
      return _mapStatus(await Permission.storage.status);
    }

    final sdkInt = await _androidSdkInt() ?? 0;
    if (sdkInt >= 33) {
      final photos = await Permission.photos.status;
      final videos = await Permission.videos.status;
      final audio = await Permission.audio.status;
      if (photos.isPermanentlyDenied || videos.isPermanentlyDenied || audio.isPermanentlyDenied) {
        return AppPermissionStatus.permanentlyDenied;
      }
      if (photos.isGranted && videos.isGranted && audio.isGranted) {
        return AppPermissionStatus.granted;
      }
      return AppPermissionStatus.denied;
    }

    if (sdkInt >= 30) {
      return _mapStatus(await Permission.manageExternalStorage.status);
    }

    return _mapStatus(await Permission.storage.status);
  }

  /// 请求蓝牙权限（Android 12+ 需要 SCAN 和 CONNECT）
  Future<AppPermissionStatus> requestBluetoothPermissions() async {
    if (!Platform.isAndroid) {
      return _mapStatus(await Permission.bluetooth.request());
    }

    final sdkInt = await _androidSdkInt() ?? 0;
    if (sdkInt < 31) {
      return _mapStatus(await Permission.bluetooth.request());
    }

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

  /// 请求文件访问权限（按 Android 版本选择权限组）
  Future<AppPermissionStatus> requestStoragePermissions() async {
    if (!Platform.isAndroid) {
      return _mapStatus(await Permission.storage.request());
    }

    final sdkInt = await _androidSdkInt() ?? 0;
    if (sdkInt >= 33) {
      final photos = await Permission.photos.request();
      final videos = await Permission.videos.request();
      final audio = await Permission.audio.request();
      if (photos.isPermanentlyDenied || videos.isPermanentlyDenied || audio.isPermanentlyDenied) {
        return AppPermissionStatus.permanentlyDenied;
      }
      if (photos.isGranted && videos.isGranted && audio.isGranted) {
        return AppPermissionStatus.granted;
      }
      return AppPermissionStatus.denied;
    }

    if (sdkInt >= 30) {
      final status = await Permission.manageExternalStorage.request();
      return _mapStatus(status);
    }

    return _mapStatus(await Permission.storage.request());
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

  Future<bool> _isPermissionAvailable(AppPermission permission) async {
    final sdkInt = await _androidSdkInt() ?? 0;

    if (Platform.isAndroid) {
      switch (permission) {
        case AppPermission.notification:
          // 通知权限只在 Android 13+ (API 33+) 需要动态请求
          return sdkInt >= 33;
        default:
          return true;
      }
    }

    return true;
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

  /// 通知权限 - Android 13+ (API 33+)
  static const List<AppPermission> notificationPermissions = [
    AppPermission.notification,
  ];

  /// 请求IMU监测所需权限
  Future<Map<AppPermission, AppPermissionStatus>> requestIMUPermissions() async {
    return {}; // 基础传感器无需请求权限
  }

  /// 检查IMU监测权限是否全部授予
  Future<bool> checkIMUPermissions() async {
    return true; // 基础传感器视为始终授权
  }

  /// 获取未授权的IMU权限列表
  Future<List<AppPermission>> getDeniedIMUPermissions() async {
    return []; // 无需授权
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

  /// 打开系统设置页面
  Future<bool> openExternalAppSettings() async {
    return openAppSettings();
  }
}
