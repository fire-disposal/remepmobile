import 'package:flutter/material.dart';

/// 事件级别
enum VisionEventLevel {
  info,
  warning,
  error,
  success,
}

/// 算法参数配置
/// 
/// 支持两种算法：
/// 1. 关键点关系分析 - 基于17个关键点的空间关系判断跌倒
/// 2. 识别框趋势分析 - 基于检测框的时序变化判断跌倒
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

  /// 创建默认参数
  factory AlgorithmParams.defaultFor(VisionAlgorithmType algorithm) {
    return switch (algorithm) {
      VisionAlgorithmType.keypointRelation => const AlgorithmParams(
          keypointConfidenceThreshold: 0.3,
          timeWindowMs: 1500,
          fallAngleThreshold: 60.0,  // 躯干角度超过60度认为可能跌倒
          aspectRatioThreshold: 1.2,
          verticalSpeedThreshold: 0.3,
          minKeyPoints: 8,  // 至少需要8个有效关键点
        ),
      VisionAlgorithmType.bboxTrend => const AlgorithmParams(
          keypointConfidenceThreshold: 0.3,
          timeWindowMs: 2000,
          fallAngleThreshold: 70.0,
          aspectRatioThreshold: 1.0,  // 框变扁认为跌倒
          verticalSpeedThreshold: 0.4,  // 快速下降
          minKeyPoints: 5,
        ),
    };
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

enum VisionModelType {
  builtinPersonFast('MoveNet (内置)', '内置轻量姿态模型，17个关键点，无需下载', Colors.lightBlue),
  poseNano('MoveNet Lightning', 'Google官方轻量姿态模型，17个关键点', Colors.teal),
  personDetectorLite('BlazePose', 'Google MediaPipe人体检测', Colors.orange),
  bodyKeypointLite('EfficientDet', '轻量级目标检测模型', Colors.purple);

  final String label;
  final String description;
  final Color accent;

  const VisionModelType(this.label, this.description, this.accent);

  /// 简短标签，用于紧凑显示
  String get shortLabel => switch (this) {
    VisionModelType.builtinPersonFast => '内置',
    VisionModelType.poseNano => 'MoveNet',
    VisionModelType.personDetectorLite => 'BlazePose',
    VisionModelType.bodyKeypointLite => 'EffDet',
  };
}

enum VisionAlgorithmType {
  keypointRelation('关键点关系', '基于17个关键点空间关系判断跌倒姿态'),
  bboxTrend('识别框趋势', '基于检测框长宽比和垂直速度变化判断');

  final String label;
  final String description;

  const VisionAlgorithmType(this.label, this.description);

  /// 简短标签，用于紧凑显示
  String get shortLabel => switch (this) {
    VisionAlgorithmType.keypointRelation => 'KeyRel',
    VisionAlgorithmType.bboxTrend => 'BBox',
  };
}

/// 视觉输出形态（决定绘制方式）
enum VisionOutputKind {
  keypoints,
  detectionBox,
}

/// 模型运行画像：将模型、算法和绘制绑定在一起
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

  String get description => switch (outputKind) {
    VisionOutputKind.keypoints => '关键点模型：使用${algorithm.label}，显示骨架关键点',
    VisionOutputKind.detectionBox => '识别框模型：使用${algorithm.label}，显示检测框',
  };
}

extension VisionModelProfileX on VisionModelType {
  /// 模型绑定算法，不再独立选择
  VisionAlgorithmType get boundAlgorithm => switch (this) {
    VisionModelType.builtinPersonFast || VisionModelType.poseNano => VisionAlgorithmType.keypointRelation,
    VisionModelType.personDetectorLite || VisionModelType.bodyKeypointLite => VisionAlgorithmType.bboxTrend,
  };

  /// 模型绑定输出形态（决定绘制方式）
  VisionOutputKind get outputKind => switch (this) {
    VisionModelType.builtinPersonFast || VisionModelType.poseNano => VisionOutputKind.keypoints,
    VisionModelType.personDetectorLite || VisionModelType.bodyKeypointLite => VisionOutputKind.detectionBox,
  };

  VisionPipelineProfile get pipeline => VisionPipelineProfile(
        model: this,
        algorithm: boundAlgorithm,
        outputKind: outputKind,
      );
}

enum VisionPermissionState {
  unknown,
  granted,
  denied,
  permanentlyDenied,
}

/// 关键点定义
class KeyPoint {
  final Offset normalizedPosition; // 0-1范围内的坐标
  final double confidence;
  final int index; // 关键点索引（COCO格式）
  final String name; // 关键点名称

  const KeyPoint({
    required this.normalizedPosition,
    required this.confidence,
    required this.index,
    required this.name,
  });
}

/// 检测框（支持关键点）
class DetectionBox {
  final Rect normalizedRect;
  final String label;
  final double confidence;
  
  /// 关键点列表（可选）
  final List<KeyPoint>? keyPoints;
  
  /// 是否包含关键点数据
  bool get hasKeyPoints => keyPoints != null && keyPoints!.isNotEmpty;

  const DetectionBox({
    required this.normalizedRect,
    required this.label,
    required this.confidence,
    this.keyPoints,
  });
}

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

  /// 获取事件级别对应的颜色
  Color getLevelColor() {
    return switch (level) {
      VisionEventLevel.info => Colors.blue,
      VisionEventLevel.warning => Colors.orange,
      VisionEventLevel.error => Colors.red,
      VisionEventLevel.success => Colors.green,
    };
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

/// 模型清单
/// 
/// 定义了模型的元数据，包括下载地址、校验信息等
class ModelManifest {
  final VisionModelType type;
  final String fileName;
  
  /// 模型下载URL
  /// 
  /// 推荐使用的可靠模型源：
  /// 1. **自托管CDN** (推荐生产环境)
  ///    - 阿里云OSS: https://your-bucket.oss-cn-region.aliyuncs.com/models/xxx.tflite
  ///    - 腾讯云COS: https://your-bucket.cos.region.myqcloud.com/models/xxx.tflite
  ///    - AWS S3: https://your-bucket.s3.region.amazonaws.com/models/xxx.tflite
  /// 
  /// 2. **GitHub Release** (适合开源项目)
  ///    - https://github.com/your-org/your-repo/releases/download/v1.0.0/xxx.tflite
  /// 
  /// 3. **Hugging Face** (适合AI模型)
  ///    - https://huggingface.co/your-username/your-model/resolve/main/xxx.tflite
  /// 
  /// 4. **备用镜像** (建议配置多个源)
  ///    - 主地址失败时自动尝试备用地址
  final String downloadUrl;
  
  /// 备用下载地址列表
  final List<String> mirrorUrls;
  
  /// 文件大小（字节），用于验证下载完整性
  final int? expectedSize;
  
  /// SHA256校验和，用于验证文件完整性
  final String? expectedSha256;
  
  /// 模型版本号
  final String version;
  
  /// 最低支持的App版本
  final String? minAppVersion;
  
  /// 模型格式类型
  final ModelFormat format;
  
  /// 显示大小标签
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
  
  /// 获取所有可用的下载URL（主地址+备用地址）
  List<String> get allUrls {
    if (downloadUrl.isEmpty) return mirrorUrls;
    return [downloadUrl, ...mirrorUrls];
  }
  
  /// 检查是否配置了下载地址
  bool get hasDownloadUrl => downloadUrl.isNotEmpty || mirrorUrls.isNotEmpty;
}

/// 模型文件格式
enum ModelFormat {
  tflite,
  onnx,
  quantizedTflite,
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
