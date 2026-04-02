import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';

import '../../../../core/mqtt/mqtt_service.dart';
import '../models/mqtt_models.dart';

/// MQTT调试服务
/// 封装MQTT操作，提供调试功能
class MqttDebugService {
  final MqttService _mqttService;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _messageSubscription;

  MqttDebugService(this._mqttService);

  /// 连接状态流
  Stream<MqttConnectionStatus> get statusStream => _mqttService.statusStream;

  /// 当前连接状态
  MqttConnectionStatus get currentStatus => _mqttService.currentStatus;

  /// 当前全局配置
  MqttConnectionConfig? get currentConfig => _mqttService.currentConfig;

  /// 连接到MQTT服务器
  Future<bool> connect(MqttConnectionConfig config) async {
    try {
      await _mqttService.connect(config);

      // 订阅消息
      _messageSubscription = _mqttService.messages?.listen((messages) {
        for (final msg in messages) {
          _handleIncomingMessage(msg);
        }
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    await _mqttService.disconnect();
  }

  /// 发布消息
  Future<bool> publish({
    required String topic,
    required String payload,
    int qos = 1,
    bool retain = false,
  }) async {
    if (_mqttService.currentStatus != MqttConnectionStatus.connected) {
      return false;
    }

    try {
      final mqttQos = qos == 0
          ? MqttQos.atMostOnce
          : qos == 1
              ? MqttQos.atLeastOnce
              : MqttQos.exactlyOnce;

      _mqttService.publish(
        topic: topic,
        message: payload,
        qos: mqttQos,
        retain: retain,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 消息流
  Stream<List<MqttReceivedMessage<MqttMessage>>>? get messages => _mqttService.messages;

  void _handleIncomingMessage(MqttReceivedMessage<MqttMessage> msg) {
    // 处理接收到的消息
    // 可以在这里添加消息处理逻辑
  }

  /// 释放资源
  void dispose() {
    _messageSubscription?.cancel();
  }
}
