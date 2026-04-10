import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../../core/events/app_event.dart';
import '../../core/events/global_event_store.dart';
import '../../core/mqtt/mqtt_config_service.dart';
import '../../core/permission/permission_service.dart';
import '../../core/utils/logger.dart';
import 'vision_detection_models.dart';

/// 瑙嗚妫€娴嬫帶鍒跺櫒
/// 
/// 浣跨敤鍥哄畾妯″瀷 YOLO11n Detect 杩涜鐩爣妫€娴?
/// 绉婚櫎浜嗘ā鍨嬪垏鎹㈠姛鑳斤紝绠€鍖栫敤鎴蜂娇鐢ㄦ祦绋?
class VisionDetectionController extends ChangeNotifier {
  VisionDetectionController({
    required MqttConfigService mqttConfigService,
    required GlobalEventStore eventStore,
    required PermissionService permissionService,
  })  : _mqttConfigService = mqttConfigService,
        _eventStore = eventStore,
        _permissionService = permissionService;

  final MqttConfigService _mqttConfigService;
  final GlobalEventStore _eventStore;
  final PermissionService _permissionService;

  bool _isInitializing = false;
  bool _isStreaming = false;
  bool _isModelLoading = false;

  // 鍥哄畾浣跨敤 YOLO11n Detect 妯″瀷
  static const VisionModelType _fixedModel = VisionModelType.builtinPersonFast;
  static const VisionAlgorithmType _fixedAlgorithm = VisionAlgorithmType.bboxTrend;
  
  VisionPermissionState _permissionState = VisionPermissionState.unknown;
  final GravitySnapshot _gravitySnapshot = const GravitySnapshot(x: 0, y: 0, z: 9.8);

  List<DetectionBox> _detections = const [];
  VisionEvent? _latestEvent;
  int _fps = 0;
  int _inferenceFps = 0;
  int _processingLatencyMs = 0;
  bool _fallAlarmOn = false;
  VisionDetectionMode _detectionMode = VisionDetectionMode.performance;

  DateTime? _lastInferenceAt;
  final List<DateTime> _recentFrames = [];

  // 妯″瀷鐘舵€?- 鍥哄畾涓哄凡灏辩华
  static const ModelRuntimeState _modelState = ModelRuntimeState(
    manifest: ModelManifest(
      type: _fixedModel,
      fileName: 'yolo11n.tflite',
      downloadUrl: '',
      sizeLabel: '鍐呯疆',
      builtIn: true,
      format: ModelFormat.tflite,
    ),
    isDownloaded: true,
  );

  // Getters
  bool get isInitializing => _isInitializing;
  bool get isStreaming => _isStreaming;
  VisionModelType get selectedModel => _fixedModel;
  VisionPipelineProfile get selectedPipeline => _fixedModel.pipeline;
  VisionAlgorithmType get selectedAlgorithm => _fixedAlgorithm;
  VisionPermissionState get permissionState => _permissionState;
  GravitySnapshot get gravitySnapshot => _gravitySnapshot;

  List<DetectionBox> get detections => _detections;
  VisionEvent? get latestEvent => _latestEvent;
  int get fps => _fps;
  int get inferenceFps => _inferenceFps;
  int get processingLatencyMs => _processingLatencyMs;
  bool get fallAlarmOn => _fallAlarmOn;
  ModelRuntimeState get modelState => _modelState;
  bool get isModelLoading => _isModelLoading;
  VisionDetectionMode get detectionMode => _detectionMode;

  bool get isModelReady => true;
  String get yoloModelPath => _fixedModel.yoloModelId;

  /// 鑾峰彇褰撳墠绠楁硶鍙傛暟
  AlgorithmParams get algorithmParams => _detectionMode.presetFor(_fixedAlgorithm);

  Future<void> initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;
    notifyListeners();

    try {
      await refreshPermission();
      _latestEvent = VisionEvent(
        title: 'YOLO 检测已就绪',
        detail: '使用 YOLO11n Detect 模型进行目标检测。',
        timestamp: DateTime.now(),
        level: VisionEventLevel.success,
      );
    } catch (e) {
      AppLogger.error('Initialization error: $e');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshPermission() async {
    final status = await _permissionService.checkPermission(AppPermission.camera);
    _permissionState = status == AppPermissionStatus.granted 
        ? VisionPermissionState.granted 
        : VisionPermissionState.denied;
    notifyListeners();
  }

  Future<void> requestPermission() async {
    final status = await _permissionService.requestPermission(AppPermission.camera);
    _permissionState = status == AppPermissionStatus.granted 
        ? VisionPermissionState.granted 
        : VisionPermissionState.denied;
    notifyListeners();
  }

  Future<void> requestPermissions() => requestPermission();

  Future<void> openSystemSettings() => _permissionService.openExternalAppSettings();

  void setDetectionMode(VisionDetectionMode mode) {
    if (_detectionMode == mode) return;
    _detectionMode = mode;
    _latestEvent = VisionEvent(
      title: '识别模式已切换',
      detail: '当前模式：${mode.label} - ${mode.description}',
      timestamp: DateTime.now(),
      level: VisionEventLevel.success,
    );
    notifyListeners();
  }

  Future<void> toggleStreaming() async {
    if (_permissionState != VisionPermissionState.granted) {
      await requestPermission();
      if (_permissionState != VisionPermissionState.granted) return;
    }

    _isStreaming = !_isStreaming;
    _detections = [];
    _inferenceFps = 0;
    _processingLatencyMs = 0;
    
    _latestEvent = VisionEvent(
      title: _isStreaming ? '识别流已启动' : '识别流已停止',
      detail: _isStreaming ? '正在接收相机数据并进行推理...' : '已停止所有推理任务。',
      timestamp: DateTime.now(),
      level: _isStreaming ? VisionEventLevel.success : VisionEventLevel.info,
    );
    
    notifyListeners();
  }

  /// 处理来自 YOLO SDK 的检测结果
  void onYoloResult(List<dynamic> results) {
    if (!_isStreaming) return;

    final now = DateTime.now();
    
    // 计算 FPS
    if (_lastInferenceAt != null) {
      final diff = now.difference(_lastInferenceAt!).inMilliseconds;
      if (diff > 0) {
        _inferenceFps = (1000 / diff).round();
        _processingLatencyMs = diff;
      }
    }
    _lastInferenceAt = now;

    // 解析结果数据
    // Ultralytics SDK 返回的对象包含: x1, y1, x2, y2, confidence, label
    // 这里的坐标已经是归一化后的 (0.0 - 1.0)
    _detections = results.map((raw) {
      try {
        final Map<String, dynamic> data = (raw as Map).cast<String, dynamic>();
        
        final double x1 = _toDouble(data['x1'] ?? data['left'] ?? 0.0) ?? 0.0;
        final double y1 = _toDouble(data['y1'] ?? data['top'] ?? 0.0) ?? 0.0;
        final double x2 = _toDouble(data['x2'] ?? data['right'] ?? 0.0) ?? 0.0;
        final double y2 = _toDouble(data['y2'] ?? data['bottom'] ?? 0.0) ?? 0.0;

        return DetectionBox(
          normalizedRect: Rect.fromLTRB(
            x1.clamp(0.0, 1.0), y1.clamp(0.0, 1.0), 
            x2.clamp(0.0, 1.0), y2.clamp(0.0, 1.0)
          ),
          label: (data['label'] ?? data['tag'] ?? 'person').toString(),
          confidence: (data['confidence'] ?? data['score'] ?? data['conf'] ?? 0.0).toDouble(),
        );
      } catch (e) {
        AppLogger.error('YOLO Parse Error: $e');
        return null;
      }
    }).whereType<DetectionBox>().toList();
    
    // 跌倒检测算法：基于框的长宽比
    final aspectRatioThreshold = algorithmParams.aspectRatioThreshold;
    final hasAbnormalPose = _detections.any((item) {
      final rect = item.normalizedRect;
      return rect.width / rect.height > aspectRatioThreshold; // 框变宽/变扁
    });

    if (hasAbnormalPose && !_fallAlarmOn) {
      AppLogger.warning('检测到疑似跌倒姿态！');
      _publishEvent();
    }
    
    _fallAlarmOn = hasAbnormalPose;

    _latestEvent = VisionEvent(
      title: _fallAlarmOn ? '⚠️ 检测到异常姿态' : 'YOLO 运行中 (${_inferenceFps} FPS)',
      detail: '视野内有 ${_detections.length} 个目标。',
      timestamp: now,
      level: _fallAlarmOn ? VisionEventLevel.warning : VisionEventLevel.info,
    );
    _eventStore.append(
      AppEvent(
        id: 'vision-${now.microsecondsSinceEpoch}',
        source: AppEventSource.vision,
        level: _fallAlarmOn ? AppEventLevel.warning : AppEventLevel.info,
        title: _latestEvent!.title,
        message: _latestEvent!.detail,
        timestamp: now,
        payload: {'detectionCount': _detections.length},
      ),
    );

    notifyListeners();
  }
  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _publishEvent() {
    final payload = jsonEncode({
      'type': 'vision_fall_alert',
      'ts': DateTime.now().toIso8601String(),
      'confidence': _detections.isNotEmpty ? _detections.first.confidence : 0,
      'model': _fixedModel.label,
      'source': 'ultralytics_yolo_flutter_sdk',
    });

    _mqttConfigService.publishJson(
      topicSuffix: 'vision/events',
      payload: payload,
      qos: MqttQos.atLeastOnce,
    );
  }

  Future<void> onPageClosed() async {
    if (_isStreaming) {
      await toggleStreaming();
    }
  }

  @override
  void dispose() {
    unawaited(onPageClosed());
    super.dispose();
  }
}
