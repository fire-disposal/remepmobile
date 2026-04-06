import 'dart:ui';

import 'package:flutter/material.dart';

enum VisionModelType {
  poseTiny('Pose Tiny', '轻量骨架检测，低延迟', Colors.lightBlue),
  personDetector('Person Detector', '通用人体框检测，兼容性高', Colors.orange),
  bodyKeypoint('Body Keypoint XL', '精度更高，耗时更长', Colors.purple);

  final String label;
  final String description;
  final Color accent;

  const VisionModelType(this.label, this.description, this.accent);
}

enum VisionAlgorithmType {
  fallRuleV1('Fall Rule V1', '阈值 + 时间窗规则'),
  motionTrend('Motion Trend', '框高宽比时序变化'),
  hybridScore('Hybrid Score', '融合重力方向与视觉分数');

  final String label;
  final String description;

  const VisionAlgorithmType(this.label, this.description);
}

class DetectionBox {
  final Rect normalizedRect;
  final String label;
  final double confidence;

  const DetectionBox({
    required this.normalizedRect,
    required this.label,
    required this.confidence,
  });
}

class VisionEvent {
  final String title;
  final String detail;
  final DateTime timestamp;

  const VisionEvent({
    required this.title,
    required this.detail,
    required this.timestamp,
  });

  String get timeLabel {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final min = timestamp.minute.toString().padLeft(2, '0');
    final sec = timestamp.second.toString().padLeft(2, '0');
    return '$hour:$min:$sec';
  }
}

class GravitySnapshot {
  final double x;
  final double y;
  final double z;

  const GravitySnapshot({required this.x, required this.y, required this.z});

  String get dominantAxis {
    final values = {
      'X': x.abs(),
      'Y': y.abs(),
      'Z': z.abs(),
    };
    final axis = values.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return axis.key;
  }
}
