import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../../core/mqtt/mqtt_models.dart';
import '../../core/mqtt/mqtt_service.dart';
import '../../core/permission/permission_service.dart';
import '../../core/utils/logger.dart';
import 'vision_detection_models.dart';

class VisionDetectionController extends ChangeNotifier {
  VisionDetectionController({
    required MqttService mqttService,
    required PermissionService permissionService,
  })  : _mqttService = mqttService,
        _permissionService = permissionService;

  final MqttService _mqttService;
  final PermissionService _permissionService;

  bool _isInitializing = false;
  bool _isStreaming = false;
  bool _isModelLoading = false;

  VisionModelType _selectedModel = VisionModelType.builtinPersonFast;
  VisionAlgorithmType _selectedAlgorithm = VisionModelType.builtinPersonFast.boundAlgorithm;
  VisionPermissionState _permissionState = VisionPermissionState.unknown;
  final GravitySnapshot _gravitySnapshot = const GravitySnapshot(x: 0, y: 0, z: 9.8);

  List<DetectionBox> _detections = const [];
  VisionEvent? _latestEvent;
  String _mqttBroker = 'broker.hivemq.com';
  int _mqttPort = 1883;
  int _fps = 0;
  int _inferenceFps = 0;
  int _processingLatencyMs = 0;
  bool _fallAlarmOn = false;
  String? _modelLoadError;
  VisionDetectionMode _detectionMode = VisionDetectionMode.balanced;

  DateTime? _lastInferenceAt;
  final List<DateTime> _recentFrames = [];

  static const List<ModelManifest> _manifests = [
    ModelManifest(
      type: VisionModelType.builtinPersonFast,
      fileName: 'yolo11n.tflite',
      downloadUrl: '',
      sizeLabel: '内置',
      builtIn: true,
      format: ModelFormat.tflite,
    ),
    ModelManifest(
      type: VisionModelType.poseNano,
      fileName: 'yolo11n-pose.tflite',
      downloadUrl: '',
      sizeLabel: '内置',
      builtIn: true,
      format: ModelFormat.tflite,
    ),
    ModelManifest(
      type: VisionModelType.personDetectorLite,
      fileName: 'yolo11n-seg.tflite',
      downloadUrl: '',
      sizeLabel: '内置',
      builtIn: true,
      format: ModelFormat.tflite,
    ),
    ModelManifest(
      type: VisionModelType.bodyKeypointLite,
      fileName: 'yolo11n-obb.tflite',
      downloadUrl: '',
      sizeLabel: '内置',
      builtIn: true,
      format: ModelFormat.tflite,
    ),
  ];

  final Map<VisionModelType, ModelRuntimeState> _modelStates = {
    for (final manifest in _manifests)
      manifest.type: ModelRuntimeState(manifest: manifest, isDownloaded: true),
  };

  bool get isInitializing => _isInitializing;
  bool get isStreaming => _isStreaming;
  VisionModelType get selectedModel => _selectedModel;
  VisionPipelineProfile get selectedPipeline => _selectedModel.pipeline;
  VisionAlgorithmType get selectedAlgorithm => _selectedAlgorithm;
  VisionPermissionState get permissionState => _permissionState;
  GravitySnapshot get gravitySnapshot => _gravitySnapshot;

  List<DetectionBox> get detections => _detections;
  VisionEvent? get latestEvent => _latestEvent;
  String get mqttBroker => _mqttBroker;
  int get mqttPort => _mqttPort;
  int get fps => _fps;
  int get inferenceFps => _inferenceFps;
  int get processingLatencyMs => _processingLatencyMs;
  bool get fallAlarmOn => _fallAlarmOn;
  List<ModelRuntimeState> get modelStates => _manifests.map((item) => _modelStates[item.type]!).toList(growable: false);
  bool get isModelLoading => _isModelLoading;
  String? get modelLoadError => _modelLoadError;
  VisionDetectionMode get detectionMode => _detectionMode;

  bool get isModelReady => true;
  String get yoloModelPath => _selectedModel.yoloModelId;

  Future<void> initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;
    notifyListeners();

    try {
      await refreshPermission();
      await _refreshModelStates();
      _latestEvent = VisionEvent(
        title: 'YOLO SDK 已就绪',
        detail: '视觉模块已切换为 Ultralytics 官方 Flutter SDK。',
        timestamp: DateTime.now(),
        level: VisionEventLevel.success,
      );
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshPermission() async {
    final statuses = await _permissionService.checkPermissions(PermissionService.visionDetectionRequiredPermissions);
    final camStatus = statuses[AppPermission.camera];
    if (camStatus == AppPermissionStatus.granted) {
      _permissionState = VisionPermissionState.granted;
    } else if (camStatus == AppPermissionStatus.permanentlyDenied) {
      _permissionState = VisionPermissionState.permanentlyDenied;
    } else {
      _permissionState = VisionPermissionState.denied;
    }
    notifyListeners();
  }

  Future<void> requestPermissions() async {
    await _permissionService.requestVisionDetectionPermissions();
    await refreshPermission();
  }

  Future<void> openSystemSettings() async {
    await _permissionService.openSettings();
  }

  Future<void> _refreshModelStates() async {
    for (final manifest in _manifests) {
      _modelStates[manifest.type] = _modelStates[manifest.type]!.copyWith(isDownloaded: true, isDownloading: false, progress: 1);
    }
    notifyListeners();
  }

  Future<void> refreshModelStates() => _refreshModelStates();

  Future<void> downloadModel(VisionModelType model) async {
    _latestEvent = VisionEvent(
      title: '无需下载模型',
      detail: '${model.label} 使用 YOLO SDK 内置模型标识，直接可运行。',
      timestamp: DateTime.now(),
    );
    _modelStates[model] = _modelStates[model]!.copyWith(isDownloaded: true, isDownloading: false, progress: 1);
    notifyListeners();
  }

  Future<void> removeModel(VisionModelType model) async {
    _latestEvent = VisionEvent(
      title: '模型由 SDK 管理',
      detail: '官方 SDK 模型路径由应用资源配置控制，不支持在运行时删除。',
      timestamp: DateTime.now(),
      level: VisionEventLevel.warning,
    );
    notifyListeners();
  }

  Future<void> toggleStreaming() async {
    _isStreaming = !_isStreaming;
    if (!_isStreaming) {
      _detections = const [];
      _fallAlarmOn = false;
      _processingLatencyMs = 0;
      _inferenceFps = 0;
      _fps = 0;
      _recentFrames.clear();
      _latestEvent = VisionEvent(
        title: '识别流已暂停',
        detail: 'YOLO 实时推理已停止。',
        timestamp: DateTime.now(),
      );
    } else {
      _latestEvent = VisionEvent(
        title: '识别流已启动',
        detail: 'YOLO 实时推理运行中。',
        timestamp: DateTime.now(),
        level: VisionEventLevel.success,
      );
    }
    notifyListeners();
  }

  void onYoloResult(List<dynamic> results) {
    if (!_isStreaming) return;

    final now = DateTime.now();
    if (_lastInferenceAt != null) {
      final elapsed = now.difference(_lastInferenceAt!).inMilliseconds;
      if (elapsed > 0) {
        _processingLatencyMs = elapsed;
        _inferenceFps = (1000 / elapsed).round();
      }
    }
    _lastInferenceAt = now;

    _recentFrames.add(now);
    _recentFrames.removeWhere((time) => now.difference(time).inSeconds >= 1);
    _fps = _recentFrames.length;

    _detections = results.map(_mapDetection).whereType<DetectionBox>().toList(growable: false);
    _fallAlarmOn = _detections.any((item) => item.normalizedRect.width / item.normalizedRect.height > 1.15);

    _latestEvent = VisionEvent(
      title: _fallAlarmOn ? '检测到疑似跌倒姿态' : 'YOLO 推理中',
      detail: '当前识别到 ${_detections.length} 个目标。',
      timestamp: now,
      level: _fallAlarmOn ? VisionEventLevel.warning : VisionEventLevel.info,
    );

    if (_fallAlarmOn) {
      _publishEvent();
    }

    notifyListeners();
  }

  DetectionBox? _mapDetection(dynamic raw) {
    try {
      final dynamic box = _readField(raw, ['box', 'boundingBox', 'rect']);
      final left = _toDouble(_readField(box ?? raw, ['left', 'x1', 'x', 'minX']));
      final top = _toDouble(_readField(box ?? raw, ['top', 'y1', 'y', 'minY']));
      final right = _toDouble(_readField(box ?? raw, ['right', 'x2', 'maxX']));
      final bottom = _toDouble(_readField(box ?? raw, ['bottom', 'y2', 'maxY']));

      if ([left, top, right, bottom].contains(null)) return null;

      final rect = Rect.fromLTRB(left!, top!, right!, bottom!);
      return DetectionBox(
        normalizedRect: Rect.fromLTRB(
          rect.left.clamp(0, 1),
          rect.top.clamp(0, 1),
          rect.right.clamp(0, 1),
          rect.bottom.clamp(0, 1),
        ),
        label: (_readField(raw, ['className', 'label', 'name']) ?? 'person').toString(),
        confidence: _toDouble(_readField(raw, ['confidence', 'score'])) ?? 0,
      );
    } catch (error, stackTrace) {
      AppLogger.warning('YOLO result parse failed: $error');
      AppLogger.debug(stackTrace.toString());
      return null;
    }
  }

  dynamic _readField(dynamic source, List<String> names) {
    if (source == null) return null;
    if (source is Map) {
      for (final name in names) {
        if (source.containsKey(name)) return source[name];
      }
    }
    if (source is List || source is String || source is num || source is bool) {
      return null;
    }
    for (final name in names) {
      try {
        switch (name) {
          case 'left':
            return (source as dynamic).left;
          case 'x1':
          case 'x':
          case 'minX':
            return (source as dynamic).x1 ?? (source as dynamic).x ?? (source as dynamic).minX;
          case 'top':
            return (source as dynamic).top;
          case 'y1':
          case 'y':
          case 'minY':
            return (source as dynamic).y1 ?? (source as dynamic).y ?? (source as dynamic).minY;
          case 'right':
            return (source as dynamic).right;
          case 'x2':
          case 'maxX':
            return (source as dynamic).x2 ?? (source as dynamic).maxX;
          case 'bottom':
            return (source as dynamic).bottom;
          case 'y2':
          case 'maxY':
            return (source as dynamic).y2 ?? (source as dynamic).maxY;
          case 'className':
            return (source as dynamic).className;
          case 'label':
            return (source as dynamic).label;
          case 'name':
            return (source as dynamic).name;
          case 'confidence':
            return (source as dynamic).confidence;
          case 'score':
            return (source as dynamic).score;
          case 'box':
            return (source as dynamic).box;
          case 'boundingBox':
            return (source as dynamic).boundingBox;
          case 'rect':
            return (source as dynamic).rect;
        }
      } catch (_) {}
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> updateMqttConfig({required String broker, required int port}) async {
    _mqttBroker = broker;
    _mqttPort = port;

    if (_mqttService.currentStatus == MqttConnectionStatus.connected) {
      await _mqttService.disconnect();
    }

    await _mqttService.connect(
      MqttConnectionConfig(
        broker: _mqttBroker,
        port: _mqttPort,
        clientId: 'remep_vision_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    notifyListeners();
  }

  Future<void> selectModel(VisionModelType model) async {
    if (_selectedModel == model) return;
    _selectedModel = model;
    _selectedAlgorithm = model.boundAlgorithm;
    _latestEvent = VisionEvent(
      title: '模型已切换',
      detail: '已切换到 ${model.label}（官方 YOLO SDK）。',
      timestamp: DateTime.now(),
      level: VisionEventLevel.success,
    );
    notifyListeners();
  }

  Future<void> preloadSelectedModel() async {
    _isModelLoading = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _isModelLoading = false;
    _modelLoadError = null;
    notifyListeners();
  }

  Future<void> switchAlgorithmByModel(VisionModelType model) async {
    await selectModel(model);
  }

  void setDetectionMode(VisionDetectionMode mode) {
    if (_detectionMode == mode) return;
    _detectionMode = mode;
    notifyListeners();
  }

  void _publishEvent() {
    if (_mqttService.currentStatus != MqttConnectionStatus.connected) return;

    final payload = jsonEncode({
      'type': 'vision_fall_alert',
      'ts': DateTime.now().toIso8601String(),
      'confidence': _detections.isNotEmpty ? _detections.first.confidence : 0,
      'model': _selectedModel.label,
      'source': 'ultralytics_yolo_flutter_sdk',
    });

    _mqttService.publish(
      topic: 'remep/vision/events',
      message: payload,
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
