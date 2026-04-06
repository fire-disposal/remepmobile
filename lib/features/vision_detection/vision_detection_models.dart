import 'dart:ui';

import 'package:flutter/material.dart';

enum VisionModelType {
  builtinPersonFast('内置 Fast Person', '内置轻量人体框模型，无需下载，低延迟', Colors.lightBlue),
  poseNano('Pose Nano', '超轻量姿态模型，适合中低端设备', Colors.teal),
  personDetectorLite('Person Detector Lite', '检测精度更稳定，下载后可离线推理', Colors.orange),
  bodyKeypointLite('Body Keypoint Lite', '带关键点能力的轻量模型', Colors.purple);

  final String label;
  final String description;
  final Color accent;

  const VisionModelType(this.label, this.description, this.accent);
}

enum VisionAlgorithmType {
  fallRuleV1('Fall Rule V1', '重力方向 + 框长宽比 + 时序变化'),
  motionTrend('Motion Trend', '框高宽比时序变化'),
  hybridScore('Hybrid Score', '融合重力方向与视觉分数');

  final String label;
  final String description;

  const VisionAlgorithmType(this.label, this.description);
}

enum VisionPermissionState {
  unknown,
  granted,
  denied,
  permanentlyDenied,
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

class ModelManifest {
  final VisionModelType type;
  final String fileName;
  final String downloadUrl;
  final String sizeLabel;
  final bool builtIn;

  const ModelManifest({
    required this.type,
    required this.fileName,
    required this.downloadUrl,
    required this.sizeLabel,
    this.builtIn = false,
  });
}

class ModelRuntimeState {
  final ModelManifest manifest;
  final bool isDownloaded;
  final bool isDownloading;
  final double progress;

  const ModelRuntimeState({
    required this.manifest,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.progress = 0,
  });

  ModelRuntimeState copyWith({
    bool? isDownloaded,
    bool? isDownloading,
    double? progress,
  }) {
    return ModelRuntimeState(
      manifest: manifest,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
    );
  }
}
