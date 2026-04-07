import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;

import '../../core/bluetooth/bluetooth_service.dart';
import '../../core/utils/logger.dart';

/// 蓝牙设备扫描状态
enum ScannerStatus {
  idle,       // 空闲
  scanning,   // 扫描中
  error,      // 错误
}

/// 蓝牙扫描控制器状态
class BluetoothScannerState {
  final ScannerStatus status;
  final List<ble.ScanResult> devices;
  final String? errorMessage;
  final int connectableCount;
  final DateTime? lastScanTime;

  const BluetoothScannerState({
    this.status = ScannerStatus.idle,
    this.devices = const [],
    this.errorMessage,
    this.connectableCount = 0,
    this.lastScanTime,
  });

  BluetoothScannerState copyWith({
    ScannerStatus? status,
    List<ble.ScanResult>? devices,
    String? errorMessage,
    int? connectableCount,
    DateTime? lastScanTime,
  }) {
    return BluetoothScannerState(
      status: status ?? this.status,
      devices: devices ?? this.devices,
      errorMessage: errorMessage ?? this.errorMessage,
      connectableCount: connectableCount ?? this.connectableCount,
      lastScanTime: lastScanTime ?? this.lastScanTime,
    );
  }

  bool get isScanning => status == ScannerStatus.scanning;
  bool get hasError => status == ScannerStatus.error;
  bool get isEmpty => devices.isEmpty;
}

/// 蓝牙扫描控制器
/// 管理蓝牙设备扫描状态和数据流
class BluetoothScannerController extends ChangeNotifier {
  final BluetoothService _bluetoothService;
  static const String _tag = 'BluetoothScannerController';

  // 状态
  BluetoothScannerState _state = const BluetoothScannerState();
  BluetoothScannerState get state => _state;

  // 扫描订阅
  StreamSubscription<ble.ScanResult>? _scanSubscription;
  Timer? _scanTimeoutTimer;

  // 扫描历史限制
  static const int _maxDevices = 100;

  BluetoothScannerController({
    required BluetoothService bluetoothService,
  }) : _bluetoothService = bluetoothService;

  /// 初始化控制器
  Future<void> initialize() async {
    AppLogger.info('[$_tag] Initializing bluetooth scanner controller...');
    await _bluetoothService.init();
    notifyListeners();
  }

  /// 开始扫描
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    if (_state.isScanning) {
      AppLogger.warning('[$_tag] Scan already in progress');
      return;
    }

    AppLogger.info('[$_tag] Starting BLE scan...');

    // 清除之前的设备列表
    _state = _state.copyWith(
      status: ScannerStatus.scanning,
      devices: [],
      errorMessage: null,
      connectableCount: 0,
    );
    notifyListeners();

    // 设置超时定时器
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = Timer(timeout, () {
      if (_state.isScanning) {
        stopScan();
      }
    });

    // 开始扫描
    try {
      _scanSubscription = _bluetoothService
          .scan(timeout: timeout)
          .listen(
            _onDeviceFound,
            onError: _onScanError,
            onDone: () {
              AppLogger.info('[$_tag] Scan completed');
              _updateStatus(ScannerStatus.idle);
            },
          );
    } catch (e) {
      _onScanError(e);
    }
  }

  /// 停止扫描
  Future<void> stopScan() async {
    if (!_state.isScanning) return;

    AppLogger.info('[$_tag] Stopping BLE scan...');

    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;

    await _scanSubscription?.cancel();
    _scanSubscription = null;

    await _bluetoothService.stopScan();

    _updateStatus(ScannerStatus.idle);
  }

  /// 切换扫描状态
  Future<void> toggleScan() async {
    if (_state.isScanning) {
      await stopScan();
    } else {
      await startScan();
    }
  }

  /// 清除设备列表
  void clearDevices() {
    _state = _state.copyWith(
      devices: [],
      connectableCount: 0,
    );
    notifyListeners();
    AppLogger.info('[$_tag] Device list cleared');
  }

  /// 设备发现处理
  void _onDeviceFound(ble.ScanResult result) {
    final devices = List<ble.ScanResult>.from(_state.devices);

    // 查找是否已存在
    final index = devices.indexWhere(
      (d) => d.device.remoteId == result.device.remoteId,
    );

    if (index >= 0) {
      // 更新现有设备
      devices[index] = result;
    } else {
      // 添加新设备
      devices.add(result);
    }

    // 按信号强度排序
    devices.sort((a, b) => b.rssi.compareTo(a.rssi));

    // 限制最大数量
    while (devices.length > _maxDevices) {
      devices.removeLast();
    }

    // 计算可连接设备数
    final connectableCount = devices
        .where((d) => d.advertisementData.connectable)
        .length;

    _state = _state.copyWith(
      devices: devices,
      connectableCount: connectableCount,
    );
    notifyListeners();
  }

  /// 扫描错误处理
  void _onScanError(Object error) {
    AppLogger.error('[$_tag] Scan error', error);

    _state = _state.copyWith(
      status: ScannerStatus.error,
      errorMessage: error.toString(),
    );
    notifyListeners();
  }

  /// 更新状态
  void _updateStatus(ScannerStatus status) {
    _state = _state.copyWith(
      status: status,
      lastScanTime: status == ScannerStatus.idle && _state.isScanning
          ? DateTime.now()
          : _state.lastScanTime,
    );
    notifyListeners();
  }

  /// 获取过滤后的设备列表
  List<ble.ScanResult> getFilteredDevices({bool onlyConnectable = false}) {
    if (!onlyConnectable) return _state.devices;
    return _state.devices
        .where((d) => d.advertisementData.connectable)
        .toList();
  }

  /// 连接设备
  Future<void> connectToDevice(ble.BluetoothDevice device) async {
    AppLogger.info('[$_tag] Connecting to device: ${device.remoteId}');

    try {
      // TODO: 实现设备连接逻辑
      // await _bluetoothService.connect(device);
      AppLogger.info('[$_tag] Connected to device: ${device.platformName}');
    } catch (e) {
      AppLogger.error('[$_tag] Failed to connect to device', e);
      rethrow;
    }
  }

  @override
  void dispose() {
    _scanTimeoutTimer?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }
}
