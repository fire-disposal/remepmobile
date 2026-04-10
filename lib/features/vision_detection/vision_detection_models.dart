import 'package:flutter/material.dart';

/// 视觉检测数据模型
/// 
/// 移除了多模型支持，现在只使用固定的 YOLO11n Detect 模型

/// 事件级别
enum VisionEventLevel {
  info,
  warning,
  error,
  success,
}

/// 算法参数配置
/// 
/// 用于跌倒检测的阈值参数
class AlgorithmParams {
  /// 关键点置信度阈值
  final double keypointConfidenceThreshold;
  
  /// 时间窗口（毫秒）
  final int timeWindowMs;
  
  /// 跌倒检测阈值（关键点角度阈值，单位：度）
  final double fallAngleThreshold;
  
  /// 识别框长宽比阈值（宽/高）
  final double aspectRatioThreshold;
  
  /// 垂直速度阈值（每秒变化的屏幕比例）
  final double verticalSpeedThreshold;
  
  /// 需要检测的关键点最小数量
  final int minKeyPoints;

  const AlgorithmParams({
    required this.keypointConfidenceThreshold,
    required this.timeWindowMs,
    required this.fallAngleThreshold,
    required this.aspectRatioThreshold,
    required this.verticalSpeedThreshold,
    required this.minKeyPoints,
  });

  /// 创建默认参数（用于识别框趋势分析）
  factory AlgorithmParams.defaultFor(VisionAlgorithmType algorithm) {
    return const AlgorithmParams(
      keypointConfidenceThreshold: 0.3,
      timeWindowMs: 2000,
      fallAngleThreshold: 70.0,
      aspectRatioThreshold: 1.0,  // 框变扁认为跌倒
      verticalSpeedThreshold: 0.4,  // 快速下降
      minKeyPoints: 5,
    );
  }

  /// 复制并修改参数
  AlgorithmParams copyWith({
    double? keypointConfidenceThreshold,
    int? timeWindowMs,
    double? fallAngleThreshold,
    double? aspectRatioThreshold,
    double? verticalSpeedThreshold,
    int? minKeyPoints,
  }) {
    return AlgorithmParams(
      keypointConfidenceThreshold: keypointConfidenceThreshold ?? this.keypointConfidenceThreshold,
      timeWindowMs: timeWindowMs ?? this.timeWindowMs,
      fallAngleThreshold: fallAngleThreshold ?? this.fallAngleThreshold,
      aspectRatioThreshold: aspectRatioThreshold ?? this.aspectRatioThreshold,
      verticalSpeedThreshold: verticalSpeedThreshold ?? this.verticalSpeedThreshold,
      minKeyPoints: minKeyPoints ?? this.minKeyPoints,
    );
  }
}

/// 识别模式
enum VisionDetectionMode {
  balanced('平衡', '通用场景，稳定与灵敏度均衡'),
  performance('流畅优先', '减少处理负载，优先保证画面流畅'),
  sensitive('灵敏', '提升跌倒捕捉灵敏度，适合高风险场景');

  final String label;
  final String description;

  const VisionDetectionMode(this.label, this.description);
}

/// 视觉算法类型
enum VisionAlgorithmType {
  keypointRelation('关键点关系', '基于关键点空间关系判断跌倒姿态'),
  bboxTrend('识别框趋势', '基于检测框长宽比和垂直速度变化判断');

  final String label;
  final String description;

  const VisionAlgorithmType(this.label, this.description);

  /// 简短标签
  String get shortLabel => switch (this) {
    VisionAlgorithmType.keypointRelation => 'KeyRel',
    VisionAlgorithmType.bboxTrend => 'BBox',
  };
}

/// 识别模式预设扩展
extension VisionDetectionModePresetX on VisionDetectionMode {
  AlgorithmParams presetFor(VisionAlgorithmType algorithm) {
    return switch ((this, algorithm)) {
      (VisionDetectionMode.performance, VisionAlgorithmType.bboxTrend) =>
        const AlgorithmParams(
          keypointConfidenceThreshold: 0.35,
          timeWindowMs: 2200,
          fallAngleThreshold: 70.0,
          aspectRatioThreshold: 1.15,
          verticalSpeedThreshold: 0.45,
          minKeyPoints: 6,
        ),
      (VisionDetectionMode.sensitive, VisionAlgorithmType.bboxTrend) =>
        const AlgorithmParams(
          keypointConfidenceThreshold: 0.25,
          timeWindowMs: 1500,
          fallAngleThreshold: 65.0,
          aspectRatioThreshold: 0.92,
          verticalSpeedThreshold: 0.28,
          minKeyPoints: 5,
        ),
      _ => AlgorithmParams.defaultFor(algorithm),
    };
  }
}

/// 视觉输出形态（决定绘制方式）
enum VisionOutputKind {
  keypoints,
  detectionBox,
}

/// 模型类型
/// 
/// 现在只保留一个固定模型：YOLO11n Detect
enum VisionModelType {
  builtinPersonFast('YOLO11n Detect', 'Ultralytics 官方目标检测模型', Colors.lightBlue);

  final String label;
  final String description;
  final Color accent;

  const VisionModelType(this.label, this.description, this.accent);

  /// 简短标签
  String get shortLabel => 'Detect';

  /// YOLO 模型标识符
  String get yoloModelId => 'yolo11n';

  /// 绑定算法
  VisionAlgorithmType get boundAlgorithm => VisionAlgorithmType.bboxTrend;

  /// 绑定输出形态
  VisionOutputKind get outputKind => VisionOutputKind.detectionBox;

  /// 管道配置
  VisionPipelineProfile get pipeline => VisionPipelineProfile(
    model: this,
    algorithm: boundAlgorithm,
    outputKind: outputKind,
  );
}

/// 视觉管道画像
class VisionPipelineProfile {
  final VisionModelType model;
  final VisionAlgorithmType algorithm;
  final VisionOutputKind outputKind;

  const VisionPipelineProfile({
    required this.model,
    required this.algorithm,
    required this.outputKind,
  });

  String get shortLabel => '${model.shortLabel}/${algorithm.shortLabel}';

  String get modelName => model.label;

  String get description => '目标检测模型：使用${algorithm.label}，显示检测框';
}

/// 权限状态
enum VisionPermissionState {
  unknown,
  granted,
  denied,
  permanentlyDenied,
}

/// 关键点定义
class KeyPoint {
  final Offset normalizedPosition;
  final double confidence;
  final int index;
  final String name;

  const KeyPoint({
    required this.normalizedPosition,
    required this.confidence,
    required this.index,
    required this.name,
  });
}

/// 检测框
class DetectionBox {
  final Rect normalizedRect;
  final String label;
  final double confidence;
  final List<KeyPoint>? keyPoints;

  bool get hasKeyPoints => keyPoints != null && keyPoints!.isNotEmpty;

  const DetectionBox({
    required this.normalizedRect,
    required this.label,
    required this.confidence,
    this.keyPoints,
  });
}

/// 视觉事件
class VisionEvent {
  final String title;
  final String detail;
  final DateTime timestamp;
  final VisionEventLevel level;

  const VisionEvent({
    required this.title,
    required this.detail,
    required this.timestamp,
    this.level = VisionEventLevel.info,
  });

  String get timeLabel {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final min = timestamp.minute.toString().padLeft(2, '0');
    final sec = timestamp.second.toString().padLeft(2, '0');
    return '$hour:$min:$sec';
  }

  Color getLevelColor() {
    return switch (level) {
      VisionEventLevel.info => Colors.blue,
      VisionEventLevel.warning => Colors.orange,
      VisionEventLevel.error => Colors.red,
      VisionEventLevel.success => Colors.green,
    };
  }
}

/// 重力感应数据
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

/// 模型清单
class ModelManifest {
  final VisionModelType type;
  final String fileName;
  final String downloadUrl;
  final List<String> mirrorUrls;
  final int? expectedSize;
  final String? expectedSha256;
  final String version;
  final String? minAppVersion;
  final ModelFormat format;
  final String sizeLabel;
  final bool builtIn;

  const ModelManifest({
    required this.type,
    required this.fileName,
    required this.downloadUrl,
    this.mirrorUrls = const [],
    this.expectedSize,
    this.expectedSha256,
    this.version = '1.0.0',
    this.minAppVersion,
    this.format = ModelFormat.tflite,
    required this.sizeLabel,
    this.builtIn = false,
  });

  List<String> get allUrls {
    if (downloadUrl.isEmpty) return mirrorUrls;
    return [downloadUrl, ...mirrorUrls];
  }

  bool get hasDownloadUrl => downloadUrl.isNotEmpty || mirrorUrls.isNotEmpty;
}

/// 模型文件格式
enum ModelFormat {
  tflite,
  onnx,
  quantizedTflite,
}

/// 模型运行时状态
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
