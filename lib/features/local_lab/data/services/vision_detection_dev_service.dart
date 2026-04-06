import 'dart:math';

class VisionDependencyState {
  const VisionDependencyState({
    required this.cameraReady,
    required this.tfliteReady,
    required this.permissionReady,
    required this.modelAssetReady,
  });

  final bool cameraReady;
  final bool tfliteReady;
  final bool permissionReady;
  final bool modelAssetReady;

  bool get allReady => cameraReady && tfliteReady && permissionReady && modelAssetReady;
}

class VisionInferenceSnapshot {
  const VisionInferenceSnapshot({
    required this.confidence,
    required this.fallSuspected,
    required this.label,
    required this.timestamp,
  });

  final double confidence;
  final bool fallSuspected;
  final String label;
  final DateTime timestamp;
}

/// 视觉识别开发服务（本地优先）
///
/// 提供依赖检查、模型加载状态与本地模拟识别结果，
/// 便于后续将真实模型推理逻辑无缝替换接入。
class VisionDetectionDevService {
  final Random _random = Random();

  Future<VisionDependencyState> checkDependencies() async {
    // 本阶段为本地开发起点，先固定输出已准备状态。
    // 后续可替换为真实插件可用性与资产文件检查。
    return const VisionDependencyState(
      cameraReady: true,
      tfliteReady: true,
      permissionReady: true,
      modelAssetReady: true,
    );
  }

  Future<bool> loadModel() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return true;
  }

  VisionInferenceSnapshot simulateInference() {
    final confidence = _random.nextDouble();
    final suspected = confidence > 0.74;

    return VisionInferenceSnapshot(
      confidence: confidence,
      fallSuspected: suspected,
      label: suspected ? '疑似跌倒' : '正常活动',
      timestamp: DateTime.now(),
    );
  }
}
