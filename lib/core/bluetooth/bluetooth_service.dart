import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;

import '../errors/exceptions.dart';

/// 蓝牙状态
enum BluetoothStatus {
  unavailable,
  unavailablePermission,
  turningOn,
  on,
  turningOff,
  off,
}

/// 蓝牙服务
/// 封装flutter_blue_plus，提供统一的蓝牙操作接口
class BluetoothService {
  final StreamController<BluetoothStatus> _statusController =
      StreamController<BluetoothStatus>.broadcast();

  Stream<BluetoothStatus> get statusStream => _statusController.stream;
  BluetoothStatus _currentStatus = BluetoothStatus.unavailable;

  /// 初始化蓝牙
  Future<void> init() async {
    // 检查蓝牙是否可用
    if (await ble.FlutterBluePlus.isSupported == false) {
      _updateStatus(BluetoothStatus.unavailable);
      return;
    }

    // 监听蓝牙状态变化
    ble.FlutterBluePlus.adapterState.listen((state) {
      _updateStatus(_mapAdapterState(state));
    });
  }

  /// 获取当前状态
  BluetoothStatus get currentStatus => _currentStatus;

  /// 检查蓝牙是否开启
  Future<bool> get isOn async {
    return await ble.FlutterBluePlus.adapterState.first == ble.BluetoothAdapterState.on;
  }

  /// 开启蓝牙 (仅Android)
  Future<void> turnOn() async {
    try {
      await ble.FlutterBluePlus.turnOn();
    } catch (e) {
      throw BluetoothException(
        message: '无法开启蓝牙',
        originalError: e,
      );
    }
  }

  /// 扫描设备
  Stream<ble.ScanResult> scan({
    Duration timeout = const Duration(seconds: 10),
    List<ble.Guid>? withServices,
  }) {
    ble.FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: withServices ?? [],
    );

    return ble.FlutterBluePlus.scanResults.expand((results) => results);
  }

  /// 停止扫描
  Future<void> stopScan() async {
    await ble.FlutterBluePlus.stopScan();
  }

  /// 连接设备
  Future<ble.BluetoothDevice> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final device = ble.BluetoothDevice.fromId(deviceId);
      await device.connect(timeout: timeout);
      return device;
    } catch (e) {
      throw BluetoothException(
        message: '连接设备失败',
        originalError: e,
      );
    }
  }

  /// 断开设备
  Future<void> disconnect(ble.BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (e) {
      throw BluetoothException(
        message: '断开设备失败',
        originalError: e,
      );
    }
  }

  /// 发现服务
  Future<List<ble.BluetoothService>> discoverServices(ble.BluetoothDevice device) async {
    try {
      return await device.discoverServices();
    } catch (e) {
      throw BluetoothException(
        message: '发现服务失败',
        originalError: e,
      );
    }
  }

  /// 读取特征值
  Future<List<int>> readCharacteristic(ble.BluetoothCharacteristic characteristic) async {
    try {
      return await characteristic.read();
    } catch (e) {
      throw BluetoothException(
        message: '读取特征值失败',
        originalError: e,
      );
    }
  }

  /// 写入特征值
  Future<void> writeCharacteristic(
    ble.BluetoothCharacteristic characteristic,
    List<int> value, {
    bool withoutResponse = false,
  }) async {
    try {
      await characteristic.write(value, withoutResponse: withoutResponse);
    } catch (e) {
      throw BluetoothException(
        message: '写入特征值失败',
        originalError: e,
      );
    }
  }

  /// 订阅特征值通知
  Stream<List<int>> subscribeToCharacteristic(
    ble.BluetoothCharacteristic characteristic,
  ) {
    return characteristic.onValueReceived;
  }

  /// 启用通知
  Future<void> enableNotifications(ble.BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(true);
    } catch (e) {
      throw BluetoothException(
        message: '启用通知失败',
        originalError: e,
      );
    }
  }

  /// 禁用通知
  Future<void> disableNotifications(ble.BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(false);
    } catch (e) {
      throw BluetoothException(
        message: '禁用通知失败',
        originalError: e,
      );
    }
  }

  void _updateStatus(BluetoothStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  BluetoothStatus _mapAdapterState(ble.BluetoothAdapterState state) {
    switch (state) {
      case ble.BluetoothAdapterState.unavailable:
        return BluetoothStatus.unavailable;
      case ble.BluetoothAdapterState.unauthorized:
        return BluetoothStatus.unavailablePermission;
      case ble.BluetoothAdapterState.turningOn:
        return BluetoothStatus.turningOn;
      case ble.BluetoothAdapterState.on:
        return BluetoothStatus.on;
      case ble.BluetoothAdapterState.turningOff:
        return BluetoothStatus.turningOff;
      case ble.BluetoothAdapterState.off:
        return BluetoothStatus.off;
      default:
        return BluetoothStatus.unavailable;
    }
  }

  void dispose() {
    _statusController.close();
  }
}