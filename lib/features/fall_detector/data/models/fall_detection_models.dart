import 'dart:convert';

import 'package:flutter/material.dart';

enum FallEventType {
  monitoring('monitoring', '监测中'),
  fallAlert('fall_alert', '疑似跌倒'),
  fallConfirmed('fall_confirmed', '跌倒确认'),
  personFall('person_fall', '人员跌倒');

  const FallEventType(this.value, this.label);
  final String value;
  final String label;
}

enum DeviceType {
  heartRateMonitor('heart_rate_monitor', '心率监测仪'),
  spo2Sensor('spo2_sensor', '血氧传感器'),
  smartWatch('smart_watch', '智能手表'),
  fallDetector('fall_detector', '跌倒检测器');

  const DeviceType(this.value, this.label);
  final String value;
  final String label;
}

class DetectionBox {
  const DetectionBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.confidence,
    this.label = 'person',
    this.source = 'unknown',
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final double confidence;
  final String label;
  final String source;

  Rect toRect(Size canvas) => Rect.fromLTWH(
        left * canvas.width,
        top * canvas.height,
        width * canvas.width,
        height * canvas.height,
      );

  double get aspectRatio => width / height;

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        'width': width,
        'height': height,
        'confidence': confidence,
        'label': label,
        'aspect_ratio': aspectRatio,
        'source': source,
      };
}

class FallInferenceResult {
  const FallInferenceResult({
    required this.box,
    required this.isFallSuspected,
    required this.isFallConfirmed,
    required this.ratioDelta,
    required this.timestamp,
    required this.modelName,
  });

  final DetectionBox box;
  final bool isFallSuspected;
  final bool isFallConfirmed;
  final double ratioDelta;
  final DateTime timestamp;
  final String modelName;
}

class FallEventPayload {
  const FallEventPayload({
    required this.serialNumber,
    required this.eventType,
    required this.inference,
  });

  final String serialNumber;
  final FallEventType eventType;
  final FallInferenceResult inference;

  Map<String, dynamic> toJson() => {
        'serial_number': serialNumber,
        'event_type': eventType.value,
        'event_label': eventType.label,
        'timestamp': inference.timestamp.toUtc().toIso8601String(),
        'model': inference.modelName,
        'confidence': inference.box.confidence,
        'bbox': inference.box.toJson(),
        'ratio_delta': inference.ratioDelta,
        'fall_suspected': inference.isFallSuspected,
        'fall_confirmed': inference.isFallConfirmed,
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class SendStatistics {
  const SendStatistics({
    this.totalSendCount = 0,
    this.lastSendTime,
    this.fallEventCount = 0,
    this.manualSendCount = 0,
    this.autoSendCount = 0,
  });

  final int totalSendCount;
  final int fallEventCount;
  final DateTime? lastSendTime;
  final int manualSendCount;
  final int autoSendCount;

  SendStatistics copyWith({
    int? totalSendCount,
    DateTime? lastSendTime,
    int? fallEventCount,
    int? manualSendCount,
    int? autoSendCount,
  }) {
    return SendStatistics(
      totalSendCount: totalSendCount ?? this.totalSendCount,
      lastSendTime: lastSendTime ?? this.lastSendTime,
      fallEventCount: fallEventCount ?? this.fallEventCount,
      manualSendCount: manualSendCount ?? this.manualSendCount,
      autoSendCount: autoSendCount ?? this.autoSendCount,
    );
  }
}

class FallDetectionMessage {
  const FallDetectionMessage({
    required this.eventType,
    required this.confidence,
    this.timestamp,
  });

  final String eventType;
  final double confidence;
  final String? timestamp;

  Map<String, dynamic> toJson() => {
        'event_type': eventType,
        'confidence': confidence,
        if (timestamp != null) 'timestamp': timestamp,
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class DeviceDataMessage {
  const DeviceDataMessage({
    required this.deviceType,
    this.timestamp,
    required this.data,
  });

  final String deviceType;
  final String? timestamp;
  final List<int> data;

  Map<String, dynamic> toJson() => {
        'device_type': deviceType,
        if (timestamp != null) 'timestamp': timestamp,
        'data': data,
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}
