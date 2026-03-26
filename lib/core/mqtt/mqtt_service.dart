import 'dart:async';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../constants/env_constants.dart';
import '../errors/exceptions.dart';

/// MQTT连接状态
enum MqttConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// MQTT服务
/// 封装mqtt_client，提供统一的MQTT操作接口
class MqttService {
  MqttServerClient? _client;
  final StreamController<MqttConnectionStatus> _statusController =
      StreamController<MqttConnectionStatus>.broadcast();

  Stream<MqttConnectionStatus> get statusStream => _statusController.stream;
  MqttConnectionStatus _currentStatus = MqttConnectionStatus.disconnected;

  /// 当前连接状态
  MqttConnectionStatus get currentStatus => _currentStatus;

  /// 连接到MQTT服务器
  Future<void> connect({
    required String clientId,
    String? username,
    String? password,
    bool useWebSocket = false,
  }) async {
    try {
      _updateStatus(MqttConnectionStatus.connecting);

      final brokerUrl = EnvConstants.mqttBrokerUrl;
      final port = EnvConstants.mqttPort;

      _client = MqttServerClient(
        useWebSocket ? 'wss://$brokerUrl' : 'mqtt://$brokerUrl',
        clientId,
      );

      _client!.port = port;

      // 连接配置
      final connMsg = MqttConnectMessage()
        ..withWillQos(MqttQos.atMostOnce);

      _client!.connectionMessage = connMsg;

      // 设置保活
      _client!.keepAlivePeriod = 60;

      // 自动重连
      _client!.autoReconnect = true;

      // 连接
      await _client!.connect(username, password);

      if (_client!.connectionStatus!.state != MqttConnectionState.connected) {
        throw MqttException(
          message: 'MQTT连接失败: ${_client!.connectionStatus!.state}',
        );
      }

      _updateStatus(MqttConnectionStatus.connected);
    } on SocketException catch (e) {
      _updateStatus(MqttConnectionStatus.error);
      throw MqttException(
        message: 'MQTT连接失败: 网络错误',
        originalError: e,
      );
    } on MqttException catch (e) {
      _updateStatus(MqttConnectionStatus.error);
      throw MqttException(
        message: 'MQTT连接失败',
        originalError: e,
      );
    } catch (e) {
      _updateStatus(MqttConnectionStatus.error);
      throw MqttException(
        message: 'MQTT连接失败',
        originalError: e,
      );
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    try {
      _updateStatus(MqttConnectionStatus.disconnecting);
      _client?.disconnect();
      _updateStatus(MqttConnectionStatus.disconnected);
    } catch (e) {
      throw MqttException(
        message: '断开MQTT连接失败',
        originalError: e,
      );
    }
  }

  /// 订阅主题
  Subscription? subscribe(String topic, {MqttQos qos = MqttQos.atMostOnce}) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      throw MqttException(message: 'MQTT未连接');
    }
    return _client?.subscribe(topic, qos);
  }

  /// 取消订阅
  void unsubscribe(String topic) {
    _client?.unsubscribe(topic);
  }

  /// 发布消息
  void publish({
    required String topic,
    required String message,
    MqttQos qos = MqttQos.atMostOnce,
    bool retain = false,
  }) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      throw MqttException(message: 'MQTT未连接');
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    _client?.publishMessage(topic, qos, builder.payload!);
  }

  /// 获取消息流
  Stream<List<MqttReceivedMessage<MqttMessage>>>? get messages {
    return _client?.updates;
  }

  void _updateStatus(MqttConnectionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  void dispose() {
    disconnect();
    _statusController.close();
  }
}