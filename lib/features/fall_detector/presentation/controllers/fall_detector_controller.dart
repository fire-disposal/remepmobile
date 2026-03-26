import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/mqtt/mqtt_service.dart';
import '../../data/models/fall_detection_models.dart';
import '../../data/services/fall_detector_service.dart';

/// 跌倒检测状态
class FallDetectorState {
  final bool isConnected;
  final String? error;
  final bool isSending;
  final SendStatistics statistics;

  const FallDetectorState({
    this.isConnected = false,
    this.error,
    this.isSending = false,
    this.statistics = const SendStatistics(),
  });

  FallDetectorState copyWith({
    bool? isConnected,
    String? error,
    bool? isSending,
    SendStatistics? statistics,
  }) {
    return FallDetectorState(
      isConnected: isConnected ?? this.isConnected,
      error: error,
      isSending: isSending ?? this.isSending,
      statistics: statistics ?? this.statistics,
    );
  }
}

/// 跌倒检测控制器
class FallDetectorController extends ChangeNotifier {
  final FallDetectorService _fallDetectorService;
  final MqttService _mqttService;

  FallDetectorState _state = const FallDetectorState();
  FallDetectorState get state => _state;

  StreamSubscription<MqttConnectionStatus>? _statusSubscription;

  // 自动发送相关
  Timer? _autoSendTimer;
  bool _autoSendEnabled = false;
  int _autoSendInterval = 5;

  FallDetectorController(this._fallDetectorService, this._mqttService) {
    _init();
  }

  void _init() {
    _statusSubscription = _mqttService.statusStream.listen((status) {
      _state = _state.copyWith(
        isConnected: status == MqttConnectionStatus.connected,
        error: status == MqttConnectionStatus.error ? '连接失败' : null,
      );
      notifyListeners();
    });

    // 初始化连接状态
    _state = _state.copyWith(
      isConnected: _mqttService.currentStatus == MqttConnectionStatus.connected,
    );
  }

  /// 发送跌倒事件
  Future<bool> sendFallEvent({
    required String serialNumber,
    required FallEventType eventType,
    required double confidence,
    bool autoTimestamp = true,
  }) async {
    if (!_fallDetectorService.isConnected) {
      _state = _state.copyWith(error: '未连接到MQTT服务器');
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(isSending: true);
    notifyListeners();

    try {
      final message = FallDetectionMessage(
        eventType: eventType.value,
        confidence: confidence.clamp(0.0, 1.0),
        timestamp: autoTimestamp ? DateTime.now().toUtc().toIso8601String() : null,
      );

      final success = await _fallDetectorService.sendFallEvent(
        serialNumber: serialNumber,
        message: message,
      );

      if (success) {
        _state = _state.copyWith(
          isSending: false,
          statistics: _state.statistics.copyWith(
            manualSendCount: _state.statistics.manualSendCount + 1,
            lastSendTime: DateTime.now(),
          ),
        );
      } else {
        _state = _state.copyWith(isSending: false, error: '发送失败');
      }

      notifyListeners();
      return success;
    } catch (e) {
      _state = _state.copyWith(isSending: false, error: e.toString());
      notifyListeners();
      return false;
    }
  }

  /// 发送设备数据
  Future<bool> sendDeviceData({
    required String serialNumber,
    required DeviceType deviceType,
    bool autoTimestamp = true,
  }) async {
    if (!_fallDetectorService.isConnected) {
      _state = _state.copyWith(error: '未连接到MQTT服务器');
      notifyListeners();
      return false;
    }

    try {
      final data = _fallDetectorService.generateMockData(deviceType);
      final message = DeviceDataMessage(
        deviceType: deviceType.value,
        timestamp: autoTimestamp ? DateTime.now().toUtc().toIso8601String() : null,
        data: data,
      );

      final success = await _fallDetectorService.sendDeviceData(
        serialNumber: serialNumber,
        message: message,
      );

      if (success) {
        _state = _state.copyWith(
          statistics: _state.statistics.copyWith(
            manualSendCount: _state.statistics.manualSendCount + 1,
            lastSendTime: DateTime.now(),
          ),
        );
        notifyListeners();
      }

      return success;
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
      return false;
    }
  }

  /// 启动自动发送
  void startAutoSend({
    required String serialNumber,
    required FallEventType eventType,
    required double confidence,
    required int intervalSeconds,
  }) {
    _autoSendEnabled = true;
    _autoSendInterval = intervalSeconds;
    notifyListeners();

    _autoSendTimer?.cancel();
    _autoSendTimer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) async {
      if (!_autoSendEnabled || !_fallDetectorService.isConnected) {
        timer.cancel();
        return;
      }

      final success = await sendFallEvent(
        serialNumber: serialNumber,
        eventType: eventType,
        confidence: confidence,
      );

      if (success) {
        _state = _state.copyWith(
          statistics: _state.statistics.copyWith(
            autoSendCount: _state.statistics.autoSendCount + 1,
          ),
        );
        notifyListeners();
      }
    });
  }

  /// 停止自动发送
  void stopAutoSend() {
    _autoSendEnabled = false;
    _autoSendTimer?.cancel();
    _autoSendTimer = null;
    notifyListeners();
  }

  /// 是否正在自动发送
  bool get isAutoSendEnabled => _autoSendEnabled;

  /// 自动发送间隔
  int get autoSendInterval => _autoSendInterval;

  /// 清除错误
  void clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _autoSendTimer?.cancel();
    super.dispose();
  }
}