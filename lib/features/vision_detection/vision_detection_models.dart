import 'package:flutter/material.dart';

/// 事件级别
enum VisionEventLevel {
  info,
  warning,
  error,
  success,
}

/// 算法参数配置
class AlgorithmParams {
  /// 置信度阈值
  final double confidenceThreshold;
  
  /// 时间窗口（毫秒）
  final int timeWindowMs;
  
  /// 长宽比阈值（用于跌倒检测）
  final double aspectRatioThreshold;
  
  /// 时序变化阈值
  final double trendThreshold;
  
  /// 垂直位置变化阈值
  final double positionDropThreshold;
  
  /// 是否启用重力方向检查
  final bool enableGravityCheck;

  const AlgorithmParams({
    required this.confidenceThreshold,
    required this.timeWindowMs,
    required this.aspectRatioThreshold,
    required this.trendThreshold,
    required this.positionDropThreshold,
    this.enableGravityCheck = true,
  });

  /// 创建默认参数
  factory AlgorithmParams.defaultFor(VisionAlgorithmType algorithm) {
    return switch (algorithm) {
      VisionAlgorithmType.fallRuleV1 => const AlgorithmParams(
          confidenceThreshold: 0.5,
          timeWindowMs: 2000,
          aspectRatioThreshold: 1.1,
          trendThreshold: 0.35,
          positionDropThreshold: 0.08,
          enableGravityCheck: true,
        ),
      VisionAlgorithmType.motionTrend => const AlgorithmParams(
          confidenceThreshold: 0.4,
          timeWindowMs: 1500,
          aspectRatioThreshold: 1.0,
          trendThreshold: 0.3,
          positionDropThreshold: 0.05,
          enableGravityCheck: false,
        ),
      VisionAlgorithmType.hybridScore => const AlgorithmParams(
          confidenceThreshold: 0.45,
          timeWindowMs: 1800,
          aspectRatioThreshold: 1.05,
          trendThreshold: 0.25,
          positionDropThreshold: 0.06,
          enableGravityCheck: true,
        ),
    };
  }

  /// 复制并修改参数
  AlgorithmParams copyWith({
    double? confidenceThreshold,
    int? timeWindowMs,
    double? aspectRatioThreshold,
    double? trendThreshold,
    double? positionDropThreshold,
    bool? enableGravityCheck,
  }) {
    return AlgorithmParams(
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      timeWindowMs: timeWindowMs ?? this.timeWindowMs,
      aspectRatioThreshold: aspectRatioThreshold ?? this.aspectRatioThreshold,
      trendThreshold: trendThreshold ?? this.trendThreshold,
      positionDropThreshold: positionDropThreshold ?? this.positionDropThreshold,
      enableGravityCheck: enableGravityCheck ?? this.enableGravityCheck,
    );
  }
}

enum VisionModelType {
  builtinPersonFast('内置 Fast Person', '内置轻量人体框模型，无需下载，低延迟', Colors.lightBlue),
  poseNano('MoveNet Lightning', 'Google官方轻量姿态模型，17个关键点', Colors.teal),
  personDetectorLite('BlazePose', 'Google MediaPipe人体检测', Colors.orange),
  bodyKeypointLite('EfficientDet', '轻量级目标检测模型', Colors.purple);

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
