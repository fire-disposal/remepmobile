import 'dart:convert';

import 'package:flutter/material.dart';

enum FallEventType {
  monitoring('monitoring', '监测中'),
  fallAlert('fall_alert', '疑似跌倒'),
  fallConfirmed('fall_confirmed', '跌倒确认');

  const FallEventType(this.value, this.label);
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
        'timestamp': inference.timestamp.toUtc().toIso8601String(),
        'serial_number': serialNumber,
        'device_type': 'fall_detector',
        'data': {
          'event_type': eventType.value,
          'event_label': eventType.label,
          'model': inference.modelName,
          'confidence': inference.box.confidence,
          'bbox': inference.box.toJson(),
          'ratio_delta': inference.ratioDelta,
          'fall_suspected': inference.isFallSuspected,
          'fall_confirmed': inference.isFallConfirmed,
        },
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class SendStatistics {
  const SendStatistics({
    this.totalSendCount = 0,
    this.lastSendTime,
    this.fallEventCount = 0,
  });

  final int totalSendCount;
  final int fallEventCount;
  final DateTime? lastSendTime;

  SendStatistics copyWith({
    int? totalSendCount,
    DateTime? lastSendTime,
    int? fallEventCount,
  }) {
    return SendStatistics(
      totalSendCount: totalSendCount ?? this.totalSendCount,
      lastSendTime: lastSendTime ?? this.lastSendTime,
      fallEventCount: fallEventCount ?? this.fallEventCount,
    );
  }
}
