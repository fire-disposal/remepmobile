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
  static const _historyKey = 'mqtt_publish_history';

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

  String buildPreviewUri({String? broker, int? port}) {
    final host = (broker ?? _config.broker).trim();
    final resolvedPort = port ?? _config.port;
    if (host.isEmpty) return '';
    if (host.contains('://')) {
      final uri = Uri.tryParse(host);
      if (uri != null && uri.hasPort) {
        return host;
      }
      return '$host:$resolvedPort';
    }
    return 'mqtt://$host:$resolvedPort';
  }

  String? validateConfig({
    required String broker,
    required int port,
    required String baseTopic,
  }) {
    if (broker.trim().isEmpty) {
      return 'Broker 地址不能为空';
    }
    if (port <= 0 || port > 65535) {
      return '端口范围应为 1-65535';
    }
    if (baseTopic.trim().isEmpty) {
      return 'Topic 前缀不能为空';
    }
    return null;
  }

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

  /// 读取已保存的发送历史（最新在前）
  List<Map<String, dynamic>> getPublishHistory({int limit = 500}) {
    final raw = _cache.read<List<dynamic>>(_historyKey) ?? <dynamic>[];
    final list = raw.cast<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList();
    // 最新在前
    list.sort((a, b) => (b['ts'] as String).compareTo(a['ts'] as String));
    if (limit > 0 && list.length > limit) {
      return list.sublist(0, limit);
    }
    return list;
  }

  /// 清空发送历史
  Future<void> clearPublishHistory() async {
    await _cache.write(_historyKey, <Map<String, dynamic>>[]);
    notifyListeners();
  }

  void _recordPublishHistory({
    required String topic,
    required String payload,
    required int qos,
    required bool retain,
  }) {
    try {
      final entry = <String, dynamic>{
        'topic': topic,
        'payload': payload,
        'qos': qos,
        'retain': retain,
        'ts': DateTime.now().toIso8601String(),
      };
      final raw = _cache.read<List<dynamic>>(_historyKey) ?? <dynamic>[];
      final list = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
      list.add(entry);
      // 限制最大条数，避免无限增长
      const maxEntries = 1000;
      if (list.length > maxEntries) {
        // 保留最新的 maxEntries
        final start = list.length - maxEntries;
        final trimmed = list.sublist(start);
        _cache.write(_historyKey, trimmed);
      } else {
        _cache.write(_historyKey, list);
      }
      notifyListeners();
    } catch (_) {
      // 忽略写入错误，避免影响主流程
    }
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
    // 记录发送历史
    _recordPublishHistory(
      topic: buildTopic(topicSuffix),
      payload: payload,
      qos: qos.index,
      retain: false,
    );
  }

  bool publishTest({
    String topicSuffix = 'diagnostics/test',
    String? payload,
    MqttQos qos = MqttQos.atLeastOnce,
  }) {
    if (_mqttService.currentStatus != MqttConnectionStatus.connected) {
      return false;
    }

    final message = payload ??
        '{"type":"mqtt_test","ts":"${DateTime.now().toIso8601String()}","topic":"${buildTopic(topicSuffix)}"}';

    _mqttService.publish(
      topic: buildTopic(topicSuffix),
      message: message,
      qos: qos,
    );
    _recordPublishHistory(
      topic: buildTopic(topicSuffix),
      payload: message,
      qos: qos.index,
      retain: false,
    );
    return true;
  }
}
