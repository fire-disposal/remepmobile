import 'dart:convert';

/// MQTT连接配置
class MqttConnectionConfig {
  final String broker;
  final int port;
  final String? username;
  final String? password;
  final String clientId;
  final int qos;
  final bool useWebSocket;

  const MqttConnectionConfig({
    required this.broker,
    this.port = 1883,
    this.username,
    this.password,
    required this.clientId,
    this.qos = 1,
    this.useWebSocket = false,
  });

  MqttConnectionConfig copyWith({
    String? broker,
    int? port,
    String? username,
    String? password,
    String? clientId,
    int? qos,
    bool? useWebSocket,
  }) {
    return MqttConnectionConfig(
      broker: broker ?? this.broker,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      clientId: clientId ?? this.clientId,
      qos: qos ?? this.qos,
      useWebSocket: useWebSocket ?? this.useWebSocket,
    );
  }

  Map<String, dynamic> toJson() => {
        'broker': broker,
        'port': port,
        'username': username,
        'password': password,
        'clientId': clientId,
        'qos': qos,
        'useWebSocket': useWebSocket,
      };

  factory MqttConnectionConfig.fromJson(Map<String, dynamic> json) {
    return MqttConnectionConfig(
      broker: json['broker'] as String,
      port: json['port'] as int? ?? 1883,
      username: json['username'] as String?,
      password: json['password'] as String?,
      clientId: json['clientId'] as String,
      qos: json['qos'] as int? ?? 1,
      useWebSocket: json['useWebSocket'] as bool? ?? false,
    );
  }
}

/// MQTT消息
class MqttMessageRecord {
  final String id;
  final String topic;
  final String payload;
  final DateTime timestamp;
  final bool isSent;
  final int qos;
  final bool retained;

  const MqttMessageRecord({
    required this.id,
    required this.topic,
    required this.payload,
    required this.timestamp,
    required this.isSent,
    this.qos = 1,
    this.retained = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
        'isSent': isSent,
        'qos': qos,
        'retained': retained,
      };

  factory MqttMessageRecord.fromJson(Map<String, dynamic> json) {
    return MqttMessageRecord(
      id: json['id'] as String,
      topic: json['topic'] as String,
      payload: json['payload'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSent: json['isSent'] as bool,
      qos: json['qos'] as int? ?? 1,
      retained: json['retained'] as bool? ?? false,
    );
  }
}

/// 跌倒检测事件类型
enum FallEventType {
  personFall('person_fall', '跌倒检测'),
  personStill('person_still', '静止检测'),
  personEnter('person_enter', '进入区域'),
  personLeave('person_leave', '离开区域'),
  personFallDown('person_fall_down', '跌倒'),
  personGetUp('person_get_up', '起身');

  final String value;
  final String label;

  const FallEventType(this.value, this.label);
}

/// 跌倒检测消息
class FallDetectionMessage {
  final String eventType;
  final double confidence;
  final String? timestamp;

  const FallDetectionMessage({
    required this.eventType,
    required this.confidence,
    this.timestamp,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'event_type': eventType,
      'confidence': confidence,
    };
    if (timestamp != null) {
      json['timestamp'] = timestamp;
    }
    return json;
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory FallDetectionMessage.fromJson(Map<String, dynamic> json) {
    return FallDetectionMessage(
      eventType: json['event_type'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      timestamp: json['timestamp'] as String?,
    );
  }
}

/// 通用数据消息
class DeviceDataMessage {
  final String deviceType;
  final String? timestamp;
  final List<int> data;

  const DeviceDataMessage({
    required this.deviceType,
    this.timestamp,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'device_type': deviceType,
      'data': data,
    };
    if (timestamp != null) {
      json['timestamp'] = timestamp;
    }
    return json;
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory DeviceDataMessage.fromJson(Map<String, dynamic> json) {
    return DeviceDataMessage(
      deviceType: json['device_type'] as String,
      timestamp: json['timestamp'] as String?,
      data: (json['data'] as List).cast<int>(),
    );
  }
}

/// 设备类型
enum DeviceType {
  heartRateMonitor('heart_rate_monitor', '心率监测器'),
  spo2Sensor('spo2_sensor', '血氧传感器'),
  smartWatch('smart_watch', '智能手表'),
  fallDetector('fall_detector', '跌倒检测器');

  final String value;
  final String label;

  const DeviceType(this.value, this.label);
}