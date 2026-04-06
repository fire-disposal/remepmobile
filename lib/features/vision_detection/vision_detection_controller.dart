import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/mqtt/mqtt_models.dart';
import '../../core/mqtt/mqtt_service.dart';
import '../../core/permission/permission_service.dart';
import 'vision_detection_models.dart';

class VisionDetectionController extends ChangeNotifier {
  VisionDetectionController({
    required MqttService mqttService,
    required PermissionService permissionService,
  }) : _mqttService = mqttService,
       _permissionService = permissionService;

  final MqttService _mqttService;
  final PermissionService _permissionService;
  final Dio _dio = Dio();

  CameraController? _cameraController;
  StreamSubscription<AccelerometerEvent>? _gravitySub;
  Timer? _mockInferenceTimer;

  bool _isInitializing = false;
  bool _isStreaming = false;
  bool _isFrameBeingProcessed = false;

  VisionModelType _selectedModel = VisionModelType.builtinPersonFast;
  VisionAlgorithmType _selectedAlgorithm = VisionAlgorithmType.fallRuleV1;
  VisionPermissionState _permissionState = VisionPermissionState.unknown;
  GravitySnapshot _gravitySnapshot = const GravitySnapshot(x: 0, y: 0, z: 9.8);
  List<DetectionBox> _detections = const [];
  VisionEvent? _latestEvent;
  String _mqttBroker = 'broker.hivemq.com';
  int _mqttPort = 1883;
  int _fps = 0;
  DateTime? _lastFrameTime;
  int _processingLatencyMs = 0;
  bool _fallAlarmOn = false;

  final List<_FrameFeature> _history = [];

  static const List<ModelManifest> _manifests = [
    ModelManifest(
      type: VisionModelType.builtinPersonFast,
      fileName: 'builtin_person_fast.tflite',
      downloadUrl: '',
      sizeLabel: '内置',
      builtIn: true,
    ),
    ModelManifest(
      type: VisionModelType.poseNano,
      fileName: 'pose_nano_v1.tflite',
      downloadUrl: 'https://example.com/models/pose_nano_v1.tflite',
      sizeLabel: '~2.3 MB',
    ),
    ModelManifest(
      type: VisionModelType.personDetectorLite,
      fileName: 'person_detector_lite_v2.tflite',
      downloadUrl: 'https://example.com/models/person_detector_lite_v2.tflite',
      sizeLabel: '~4.7 MB',
    ),
    ModelManifest(
      type: VisionModelType.bodyKeypointLite,
      fileName: 'body_keypoint_lite_v1.tflite',
      downloadUrl: 'https://example.com/models/body_keypoint_lite_v1.tflite',
      sizeLabel: '~7.1 MB',
    ),
  ];

  final Map<VisionModelType, ModelRuntimeState> _modelStates = {
    for (final m in _manifests)
      m.type: ModelRuntimeState(manifest: m, isDownloaded: m.builtIn),
  };

  CameraController? get cameraController => _cameraController;
  bool get isInitializing => _isInitializing;
  bool get isStreaming => _isStreaming;
  VisionModelType get selectedModel => _selectedModel;
  VisionAlgorithmType get selectedAlgorithm => _selectedAlgorithm;
  VisionPermissionState get permissionState => _permissionState;
  GravitySnapshot get gravitySnapshot => _gravitySnapshot;
  List<DetectionBox> get detections => _detections;
  VisionEvent? get latestEvent => _latestEvent;
  String get mqttBroker => _mqttBroker;
  int get mqttPort => _mqttPort;
  int get fps => _fps;
  int get processingLatencyMs => _processingLatencyMs;
  bool get fallAlarmOn => _fallAlarmOn;
  List<ModelRuntimeState> get modelStates =>
      _manifests.map((m) => _modelStates[m.type]!).toList(growable: false);

  Future<void> initialize() async {
    if (_isInitializing) {
      return;
    }

    _isInitializing = true;
    notifyListeners();

    try {
      await refreshPermission();
      await _initGravity();
      await _refreshModelStates();
      if (_permissionState == VisionPermissionState.granted) {
        await _initCamera();
      }
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshPermission() async {
    final statuses = await _permissionService.checkPermissions([
      AppPermission.camera,
      AppPermission.sensors,
    ]);
    final camStatus = statuses[AppPermission.camera];
    final sensorStatus = statuses[AppPermission.sensors];

    if (camStatus == AppPermissionStatus.granted &&
        sensorStatus == AppPermissionStatus.granted) {
      _permissionState = VisionPermissionState.granted;
    } else if (camStatus == AppPermissionStatus.permanentlyDenied ||
        sensorStatus == AppPermissionStatus.permanentlyDenied) {
      _permissionState = VisionPermissionState.permanentlyDenied;
    } else {
      _permissionState = VisionPermissionState.denied;
    }
    notifyListeners();
  }

  Future<void> requestPermissions() async {
    await _permissionService.requestPermissions([
      AppPermission.camera,
      AppPermission.sensors,
    ]);
    await refreshPermission();
    if (_permissionState == VisionPermissionState.granted &&
        _cameraController == null) {
      await _initCamera();
    }
  }

  Future<void> openSystemSettings() async {
    await _permissionService.openSettings();
  }

  Future<void> _refreshModelStates() async {
    final dir = await _modelDirectory();
    for (final manifest in _manifests) {
      if (manifest.builtIn) {
        _modelStates[manifest.type] = _modelStates[manifest.type]!.copyWith(
          isDownloaded: true,
          progress: 1,
        );
        continue;
      }
      final file = File('${dir.path}/${manifest.fileName}');
      _modelStates[manifest.type] = _modelStates[manifest.type]!.copyWith(
        isDownloaded: await file.exists(),
      );
    }
    notifyListeners();
  }

  Future<Directory> _modelDirectory() async {
    final baseDir = await getApplicationSupportDirectory();
    final dir = Directory('${baseDir.path}/vision_models');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> downloadModel(VisionModelType model) async {
    final state = _modelStates[model];
    if (state == null || state.manifest.builtIn || state.isDownloading) {
      return;
    }

    final manifest = state.manifest;
    final dir = await _modelDirectory();
    final filePath = '${dir.path}/${manifest.fileName}';

    _modelStates[model] = state.copyWith(isDownloading: true, progress: 0);
    _latestEvent = VisionEvent(
      title: '模型下载开始',
      detail: '${manifest.type.label} 下载中...',
      timestamp: DateTime.now(),
    );
    notifyListeners();

    try {
      await _dio.download(
        manifest.downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          final progress = total <= 0 ? 0 : received / total;
          final current = _modelStates[model];
          if (current == null) {
            return;
          }
          _modelStates[model] = current.copyWith(progress: progress);
          notifyListeners();
        },
      );
      final current = _modelStates[model];
      if (current != null) {
        _modelStates[model] = current.copyWith(
          isDownloading: false,
          isDownloaded: true,
          progress: 1,
        );
      }
      _latestEvent = VisionEvent(
        title: '模型下载完成',
        detail: '${manifest.type.label} 已可用于推理。',
        timestamp: DateTime.now(),
      );
    } catch (_) {
      final current = _modelStates[model];
      if (current != null) {
        _modelStates[model] = current.copyWith(isDownloading: false, progress: 0);
      }
      _latestEvent = VisionEvent(
        title: '模型下载失败',
        detail: '${manifest.type.label} 下载失败，请检查网络后重试。',
        timestamp: DateTime.now(),
      );
    }
    notifyListeners();
  }

  Future<void> removeModel(VisionModelType model) async {
    final state = _modelStates[model];
    if (state == null || state.manifest.builtIn || state.isDownloading) {
      return;
    }
    final dir = await _modelDirectory();
    final file = File('${dir.path}/${state.manifest.fileName}');
    if (await file.exists()) {
      await file.delete();
    }
    _modelStates[model] = state.copyWith(isDownloaded: false, progress: 0);
    if (_selectedModel == model) {
      _selectedModel = VisionModelType.builtinPersonFast;
    }
    _latestEvent = VisionEvent(
      title: '模型已移除',
      detail: '${state.manifest.type.label} 已从本地删除。',
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> _initGravity() async {
    await _gravitySub?.cancel();
    _gravitySub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((event) {
      _gravitySnapshot = GravitySnapshot(x: event.x, y: event.y, z: event.z);
      notifyListeners();
    });
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.where((e) => e.lensDirection == CameraLensDirection.back);
    final camera = backCamera.isNotEmpty ? backCamera.first : cameras.first;

    final old = _cameraController;
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.yuv420,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    await old?.dispose();
  }

  Future<void> toggleStreaming() async {
    if (_permissionState != VisionPermissionState.granted) {
      _latestEvent = VisionEvent(
        title: '权限未就绪',
        detail: '请先授予摄像头与运动传感器权限。',
        timestamp: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    if (_isStreaming) {
      _stopStreaming();
      return;
    }

    _isStreaming = true;
    _fallAlarmOn = false;
    _history.clear();
    _latestEvent = VisionEvent(
      title: '视频流启动',
      detail: '模型 ${_selectedModel.label} + 算法 ${_selectedAlgorithm.label} 已激活。',
      timestamp: DateTime.now(),
    );
    notifyListeners();

    _mockInferenceTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      unawaited(_processFrame());
    });
  }

  Future<void> _processFrame() async {
    if (_isFrameBeingProcessed || !_isStreaming) {
      return;
    }

    _isFrameBeingProcessed = true;
    final start = DateTime.now();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 35));
      _detections = _runMockPersonInference();

      final now = DateTime.now();
      if (_lastFrameTime != null) {
        final interval = now.difference(_lastFrameTime!).inMilliseconds;
        if (interval > 0) {
          _fps = (1000 / interval).round();
        }
      }
      _lastFrameTime = now;
      _processingLatencyMs = now.difference(start).inMilliseconds;

      _evaluateEvent();
    } finally {
      _isFrameBeingProcessed = false;
      notifyListeners();
    }
  }

  List<DetectionBox> _runMockPersonInference() {
    final random = Random();
    final simulatedFallProgress = max(0.0, min(1.0, sin(DateTime.now().millisecond / 1000 * pi)));

    final x = 0.33 + random.nextDouble() * 0.25;
    final y = 0.10 + simulatedFallProgress * 0.42;
    final width = 0.18 + simulatedFallProgress * 0.26 + random.nextDouble() * 0.05;
    final height = 0.52 - simulatedFallProgress * 0.28 + random.nextDouble() * 0.04;

    return [
      DetectionBox(
        normalizedRect: Rect.fromLTWH(
          x.clamp(0.02, 0.95),
          y.clamp(0.02, 0.95),
          width.clamp(0.1, 0.7),
          height.clamp(0.15, 0.7),
        ),
        label: 'Person',
        confidence: 0.78 + random.nextDouble() * 0.18,
      ),
    ];
  }

  void _evaluateEvent() {
    if (_detections.isEmpty) {
      return;
    }

    final box = _detections.first;
    final ratio = box.normalizedRect.width / box.normalizedRect.height;
    final centerY = box.normalizedRect.center.dy;

    final frame = _FrameFeature(
      ts: DateTime.now(),
      aspectRatio: ratio,
      centerY: centerY,
      dominantAxis: _gravitySnapshot.dominantAxis,
    );
    _history.add(frame);

    final cutoff = DateTime.now().subtract(const Duration(seconds: 2));
    _history.removeWhere((f) => f.ts.isBefore(cutoff));

    final first = _history.first;
    final ratioGrowth = ratio - first.aspectRatio;
    final dropDistance = centerY - first.centerY;
    final visualLying = ratio > 1.1;
    final trendFast = ratioGrowth > 0.35 && dropDistance > 0.08;
    final gravitySupport = _gravitySnapshot.dominantAxis != 'Z';

    final fallDetected = switch (_selectedAlgorithm) {
      VisionAlgorithmType.fallRuleV1 => visualLying && trendFast && gravitySupport,
      VisionAlgorithmType.motionTrend => visualLying && trendFast,
      VisionAlgorithmType.hybridScore => visualLying && (trendFast || gravitySupport),
    };

    if (fallDetected && !_fallAlarmOn) {
      _fallAlarmOn = true;
      _latestEvent = VisionEvent(
        title: '疑似跌倒事件',
        detail:
            'ratio=${ratio.toStringAsFixed(2)}, Δratio=${ratioGrowth.toStringAsFixed(2)}, '
            'Δy=${dropDistance.toStringAsFixed(2)}, 重力轴=${_gravitySnapshot.dominantAxis}',
        timestamp: DateTime.now(),
      );
      _publishEvent();
      return;
    }

    if (!fallDetected && _fallAlarmOn && ratio < 0.85) {
      _fallAlarmOn = false;
      _latestEvent = VisionEvent(
        title: '跌倒告警解除',
        detail: '人体框比例恢复直立趋势。',
        timestamp: DateTime.now(),
      );
    }
  }

  Future<void> updateMqttConfig({required String broker, required int port}) async {
    _mqttBroker = broker;
    _mqttPort = port;
    notifyListeners();

    await _mqttService.disconnect();
    await _mqttService.connect(
      MqttConnectionConfig(
        broker: broker,
        port: port,
        clientId: 'remep_vision_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
  }

  void selectModel(VisionModelType model) {
    final state = _modelStates[model];
    if (state == null || (!state.manifest.builtIn && !state.isDownloaded)) {
      _latestEvent = VisionEvent(
        title: '模型不可用',
        detail: '${model.label} 尚未下载，无法切换。',
        timestamp: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    _selectedModel = model;
    _latestEvent = VisionEvent(
      title: '模型切换',
      detail: '当前模型：${model.label}',
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  void selectAlgorithm(VisionAlgorithmType algorithm) {
    _selectedAlgorithm = algorithm;
    _latestEvent = VisionEvent(
      title: '算法切换',
      detail: '当前算法：${algorithm.label}',
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  void _publishEvent() {
    if (_mqttService.currentStatus != MqttConnectionStatus.connected || _latestEvent == null) {
      return;
    }

    _mqttService.publish(
      topic: 'remep/vision/events',
      qos: MqttQos.atLeastOnce,
      message:
          '{"title":"${_latestEvent!.title}","detail":"${_latestEvent!.detail}","ts":"${_latestEvent!.timestamp.toIso8601String()}"}',
    );
  }

  void _stopStreaming() {
    _mockInferenceTimer?.cancel();
    _mockInferenceTimer = null;
    _isStreaming = false;
    _fallAlarmOn = false;
    _history.clear();
    _detections = const [];
    _latestEvent = VisionEvent(
      title: '视频流暂停',
      detail: '已停止采样与推理。',
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _mockInferenceTimer?.cancel();
    _gravitySub?.cancel();
    _cameraController?.dispose();
    _dio.close();
    super.dispose();
  }
}

class _FrameFeature {
  final DateTime ts;
  final double aspectRatio;
  final double centerY;
  final String dominantAxis;

  const _FrameFeature({
    required this.ts,
    required this.aspectRatio,
    required this.centerY,
    required this.dominantAxis,
  });
}
