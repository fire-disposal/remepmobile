import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/mqtt/mqtt_models.dart';
import '../../core/mqtt/mqtt_service.dart';
import 'vision_detection_models.dart';

class VisionDetectionController extends ChangeNotifier {
  VisionDetectionController({required MqttService mqttService})
      : _mqttService = mqttService;

  final MqttService _mqttService;
  CameraController? _cameraController;
  StreamSubscription<AccelerometerEvent>? _gravitySub;
  Timer? _mockInferenceTimer;

  bool _isInitializing = false;
  bool _isStreaming = false;
  bool _isFrameBeingProcessed = false;

  VisionModelType _selectedModel = VisionModelType.poseTiny;
  VisionAlgorithmType _selectedAlgorithm = VisionAlgorithmType.fallRuleV1;
  GravitySnapshot _gravitySnapshot = const GravitySnapshot(x: 0, y: 0, z: 9.8);
  List<DetectionBox> _detections = const [];
  VisionEvent? _latestEvent;
  String _mqttBroker = 'broker.hivemq.com';
  int _mqttPort = 1883;
  int _fps = 0;
  DateTime? _lastFrameTime;
  int _processingLatencyMs = 0;

  CameraController? get cameraController => _cameraController;
  bool get isInitializing => _isInitializing;
  bool get isStreaming => _isStreaming;
  VisionModelType get selectedModel => _selectedModel;
  VisionAlgorithmType get selectedAlgorithm => _selectedAlgorithm;
  GravitySnapshot get gravitySnapshot => _gravitySnapshot;
  List<DetectionBox> get detections => _detections;
  VisionEvent? get latestEvent => _latestEvent;
  String get mqttBroker => _mqttBroker;
  int get mqttPort => _mqttPort;
  int get fps => _fps;
  int get processingLatencyMs => _processingLatencyMs;

  Future<void> initialize() async {
    if (_isInitializing) {
      return;
    }

    _isInitializing = true;
    notifyListeners();

    try {
      await _initGravity();
      await _initCamera();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
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
    if (_isStreaming) {
      _stopStreaming();
      return;
    }

    _isStreaming = true;
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
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final random = Random();
      final headX = 0.3 + random.nextDouble() * 0.4;
      final headY = 0.15 + random.nextDouble() * 0.5;
      final width = 0.25 + random.nextDouble() * 0.08;
      final height = 0.35 + random.nextDouble() * 0.2;

      _detections = [
        DetectionBox(
          normalizedRect: Rect.fromLTWH(
            headX.clamp(0.02, 0.95),
            headY.clamp(0.02, 0.95),
            width.clamp(0.10, 0.6),
            height.clamp(0.12, 0.7),
          ),
          label: 'Person',
          confidence: 0.75 + random.nextDouble() * 0.2,
        ),
      ];

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

  void _evaluateEvent() {
    if (_detections.isEmpty) {
      return;
    }

    final ratio = _detections.first.normalizedRect.width /
        _detections.first.normalizedRect.height;
    final mayFallByVisual = ratio > 0.85;
    final mayFallByGravity = _gravitySnapshot.dominantAxis == 'X';

    if (mayFallByVisual || (_selectedAlgorithm == VisionAlgorithmType.hybridScore && mayFallByGravity)) {
      _latestEvent = VisionEvent(
        title: '疑似跌倒事件',
        detail:
            '视觉比值 ${ratio.toStringAsFixed(2)}，重力主轴 ${_gravitySnapshot.dominantAxis}，算法 ${_selectedAlgorithm.label}',
        timestamp: DateTime.now(),
      );
      _publishEvent();
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
    super.dispose();
  }
}
