import 'dart:async';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

authimport 'mqtt_models.dart';
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

  MqttConnectionConfig? _currentConfig;

  Stream<MqttConnectionStatus> get statusStream => _statusController.stream;
  MqttConnectionStatus _currentStatus = MqttConnectionStatus.disconnected;

  /// 当前连接状态
  MqttConnectionStatus get currentStatus => _currentStatus;

  /// 当前全局配置
  MqttConnectionConfig? get currentConfig => _currentConfig;

  /// 使用指定配置连接到MQTT服务器
  Future<void> connect(MqttConnectionConfig config) async {
    _currentConfig = config;
    try {
      _updateStatus(MqttConnectionStatus.connecting);

      final protocol = config.useWebSocket ? 'wss://' : 'mqtt://';
      final serverUri = '$protocol${config.broker}';

      _client = MqttServerClient(serverUri, config.clientId);
      _client!.port = config.port;
      _client!.keepAlivePeriod = config.keepAlive;
      _client!.autoReconnect = config.autoReconnect;
      _client!.useWebSocket = config.useWebSocket;
      _client!.secure = config.useWebSocket;
      _client!.setProtocolV311();

      // 连接消息配置
      final connMsg = MqttConnectMessage()
        ..withClientIdentifier(config.clientId)
        ..withWillQos(_mapQos(config.qos));

      if (config.cleanSession) {
        connMsg.startClean();
      }

      // 遗嘱消息
      if (config.willTopic != null &&
          config.willTopic!.isNotEmpty &&
          config.willMessage != null) {
        connMsg.withWillTopic(config.willTopic!);
        connMsg.withWillMessage(config.willMessage!);
        connMsg.withWillQos(_mapQos(config.willQos));
        if (config.willRetain) {
          connMsg.withWillRetain();
        }
      }

        _client!.connectionMessage = connMsg;
      _client!.connectTimeoutPeriod = config.connectionTimeout * 1000;

      // 连接
      await _client!.connect(
        config.username,
        config.password,
      );

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

  MqttQos _mapQos(int qos) {
    switch (qos) {
      case 0:
        return MqttQos.atMostOnce;
      case 1:
        return MqttQos.atLeastOnce;
      case 2:
        return MqttQos.exactlyOnce;
      default:
        return MqttQos.atMostOnce;
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
      throw const MqttException(message: 'MQTT未连接');
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
      throw const MqttException(message: 'MQTT未连接');
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
