import 'dart:convert';

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

/// 发送统计
class SendStatistics {
  final int manualSendCount;
  final int autoSendCount;
  final DateTime? lastSendTime;

  const SendStatistics({
    this.manualSendCount = 0,
    this.autoSendCount = 0,
    this.lastSendTime,
  });

  SendStatistics copyWith({
    int? manualSendCount,
    int? autoSendCount,
    DateTime? lastSendTime,
  }) {
    return SendStatistics(
      manualSendCount: manualSendCount ?? this.manualSendCount,
      autoSendCount: autoSendCount ?? this.autoSendCount,
      lastSendTime: lastSendTime ?? this.lastSendTime,
    );
  }

  int get totalSendCount => manualSendCount + autoSendCount;
}