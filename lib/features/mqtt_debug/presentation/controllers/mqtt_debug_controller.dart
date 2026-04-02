import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../../data/models/mqtt_models.dart';
import '../../data/services/mqtt_debug_service.dart';
import '../../../../core/mqtt/mqtt_service.dart';
import '../../../../core/storage/cache_service.dart';

const _mqttConfigCacheKey = 'mqtt_connection_config';

/// MQTT调试状态
class MqttDebugState {
  final bool isConnected;
  final String? error;
  final MqttConnectionConfig? config;
  final List<MqttMessageRecord> messageHistory;

  const MqttDebugState({
    this.isConnected = false,
    this.error,
    this.config,
    this.messageHistory = const [],
  });

  MqttDebugState copyWith({
    bool? isConnected,
    String? error,
    MqttConnectionConfig? config,
    List<MqttMessageRecord>? messageHistory,
  }) {
    return MqttDebugState(
      isConnected: isConnected ?? this.isConnected,
      error: error,
      config: config ?? this.config,
      messageHistory: messageHistory ?? this.messageHistory,
    );
  }
}

/// MQTT调试控制器
class MqttDebugController extends ChangeNotifier {
  final MqttDebugService _mqttDebugService;
  final CacheStorageService _cacheStorage;

  MqttDebugState _state = const MqttDebugState();
  MqttDebugState get state => _state;

  StreamSubscription<MqttConnectionStatus>? _statusSubscription;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _messageSubscription;

  MqttDebugController(this._mqttDebugService, this._cacheStorage) {
    _init();
  }

  void _init() {
    _statusSubscription = _mqttDebugService.statusStream.listen((status) {
      _state = _state.copyWith(
        isConnected: status == MqttConnectionStatus.connected,
        error: status == MqttConnectionStatus.error ? '连接失败' : null,
      );
      notifyListeners();
    });

    _loadSavedConfig();
  }

  /// 加载缓存的配置
  Future<void> _loadSavedConfig() async {
    try {
      final raw = _cacheStorage.read<String>(_mqttConfigCacheKey);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final config = MqttConnectionConfig.fromJson(json);
        _state = _state.copyWith(config: config);
        notifyListeners();
      }
    } catch (e) {
      // 忽略加载错误
    }
  }

  /// 获取当前缓存的配置（供页面初始化使用）
  MqttConnectionConfig? get cachedConfig => state.config ?? _mqttDebugService.currentConfig;

  /// 保存配置到缓存
  Future<void> _saveConfig(MqttConnectionConfig config) async {
    try {
      await _cacheStorage.write(_mqttConfigCacheKey, jsonEncode(config.toJson()));
    } catch (e) {
      // 忽略保存错误
    }
  }

  /// 连接到MQTT服务器
  Future<bool> connect(MqttConnectionConfig config) async {
    try {
      _state = _state.copyWith(config: config, error: null);
      notifyListeners();

      await _saveConfig(config);

      final success = await _mqttDebugService.connect(config);
      if (!success) {
        _state = _state.copyWith(error: '连接失败');
        notifyListeners();
        return false;
      }

      // 订阅消息
      _messageSubscription = _mqttDebugService.messages?.listen((messages) {
        for (final msg in messages) {
          final payload = msg.payload as MqttPublishMessage;
          final payloadBytes = payload.payload.message;
          final message = MqttMessageRecord(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            topic: msg.topic,
            payload: String.fromCharCodes(payloadBytes),
            timestamp: DateTime.now(),
            isSent: false,
          );
          _addMessage(message);
        }
      });

      return true;
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _mqttDebugService.disconnect();
    await _messageSubscription?.cancel();
    _messageSubscription = null;
  }

  /// 发布消息
  Future<bool> publish({
    required String topic,
    required String payload,
    int qos = 1,
    bool retain = false,
  }) async {
      if (!state.isConnected) {
      _state = _state.copyWith(error: '未连接到MQTT服务器');
      notifyListeners();
      return false;
    }

    try {
      await _mqttDebugService.publish(
        topic: topic,
        payload: payload,
        qos: qos,
        retain: retain,
      );

      // 记录发送的消息
      final message = MqttMessageRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        topic: topic,
        payload: payload,
        timestamp: DateTime.now(),
        isSent: true,
        qos: qos,
        retained: retain,
      );
      _addMessage(message);

      return true;
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
      return false;
    }
  }

  void _addMessage(MqttMessageRecord message) {
    final newHistory = [message, ...state.messageHistory];
    // 保留最近100条消息
    if (newHistory.length > 100) {
      newHistory.removeRange(100, newHistory.length);
    }
    _state = _state.copyWith(messageHistory: newHistory);
    notifyListeners();
  }

  /// 清空消息历史
  void clearHistory() {
    _state = _state.copyWith(messageHistory: []);
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }
}
