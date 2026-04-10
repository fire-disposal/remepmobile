import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../constants/app_constants.dart';
import '../constants/env_constants.dart';
import '../storage/cache_service.dart';
import 'mqtt_models.dart';
import 'mqtt_service.dart';

class MqttRuntimeConfig {
  const MqttRuntimeConfig({
    required this.broker,
    required this.port,
    required this.baseTopic,
  });

  final String broker;
  final int port;
  final String baseTopic;

  MqttRuntimeConfig copyWith({
    String? broker,
    int? port,
    String? baseTopic,
  }) {
    return MqttRuntimeConfig(
      broker: broker ?? this.broker,
      port: port ?? this.port,
      baseTopic: baseTopic ?? this.baseTopic,
    );
  }
}

class MqttConfigService extends ChangeNotifier {
  MqttConfigService(this._cache, this._mqttService)
      : _config = const MqttRuntimeConfig(
          broker: 'broker.hivemq.com',
          port: 1883,
          baseTopic: 'remep/mobile',
        );

  final CacheStorageService _cache;
  final MqttService _mqttService;

  static const _brokerKey = 'mqtt_broker';
  static const _portKey = 'mqtt_port';
  static const _baseTopicKey = 'mqtt_base_topic';

  MqttRuntimeConfig _config;
  MqttRuntimeConfig get config => _config;

  Future<void> initialize() async {
    // 从环境变量加载初始值
    String broker = EnvConstants.mqttBrokerUrl;
    if (broker.isEmpty) {
      broker = 'broker.hivemq.com';
    }
    
    _config = MqttRuntimeConfig(
      broker: _cache.read<String>(_brokerKey) ?? broker,
      port: _cache.read<int>(_portKey) ?? EnvConstants.mqttPort,
      baseTopic: _cache.read<String>(_baseTopicKey) ?? _config.baseTopic,
    );
    notifyListeners();
  }

  String buildTopic(String suffix) => '${_config.baseTopic}/$suffix';

  Future<void> updateConfig({
    required String broker,
    required int port,
    required String baseTopic,
  }) async {
    _config = MqttRuntimeConfig(
      broker: broker,
      port: port,
      baseTopic: baseTopic,
    );
    await _cache.write(_brokerKey, broker);
    await _cache.write(_portKey, port);
    await _cache.write(_baseTopicKey, baseTopic);
    await reconnect();
    notifyListeners();
  }

  Future<void> reconnect() async {
    if (_mqttService.currentStatus == MqttConnectionStatus.connected) {
      await _mqttService.disconnect();
    }

    await _mqttService.connect(
      MqttConnectionConfig(
        broker: _config.broker,
        port: _config.port,
        clientId: 'remep_mobile_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
  }

  void publishJson({
    required String topicSuffix,
    required String payload,
    MqttQos qos = MqttQos.atLeastOnce,
  }) {
    if (_mqttService.currentStatus != MqttConnectionStatus.connected) {
      return;
    }

    _mqttService.publish(
      topic: buildTopic(topicSuffix),
      message: payload,
      qos: qos,
    );
  }
}
