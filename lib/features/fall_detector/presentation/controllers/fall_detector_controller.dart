import 'dart:async';
import 'dart:collection';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../core/mqtt/mqtt_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../data/models/fall_detection_models.dart';
import '../../data/services/fall_detector_service.dart';
import '../../data/services/lite_human_detector.dart';
import '../../data/services/model_manager_service.dart';

class FallDetectorState {
  const FallDetectorState({
    this.isConnected = false,
    this.permissionGranted = false,
    this.cameraReady = false,
    this.detecting = false,
    this.error,
    this.lastInference,
    this.statistics = const SendStatistics(),
    this.modelState = const ModelManagerState(),
  });

  final bool isConnected;
  final bool permissionGranted;
  final bool cameraReady;
  final bool detecting;
  final String? error;
  final FallInferenceResult? lastInference;
  final SendStatistics statistics;
  final ModelManagerState modelState;

  FallDetectorState copyWith({
    bool? isConnected,
    bool? permissionGranted,
    bool? cameraReady,
    bool? detecting,
    String? error,
    FallInferenceResult? lastInference,
    SendStatistics? statistics,
    ModelManagerState? modelState,
  }) {
    return FallDetectorState(
      isConnected: isConnected ?? this.isConnected,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      cameraReady: cameraReady ?? this.cameraReady,
      detecting: detecting ?? this.detecting,
      error: error,
      lastInference: lastInference ?? this.lastInference,
      statistics: statistics ?? this.statistics,
      modelState: modelState ?? this.modelState,
    );
  }
}

class FallDetectorController extends ChangeNotifier {
  FallDetectorController(
    this._service,
    this._mqttService,
    this._permissionService,
    this._modelManager,
  ) {
    _statusSubscription = _mqttService.statusStream.listen((status) {
      _state = _state.copyWith(
        isConnected: status == MqttConnectionStatus.connected,
        error: status == MqttConnectionStatus.error ? 'MQTT连接异常' : _state.error,
      );
      notifyListeners();
    });

    _state = _state.copyWith(
      isConnected: _mqttService.currentStatus == MqttConnectionStatus.connected,
    );
  }

  final FallDetectorService _service;
  final MqttService _mqttService;
  final PermissionService _permissionService;
  final ModelManagerService _modelManager;
  final LiteHumanDetector _detector = LiteHumanDetector();

  static const modelConfig = ModelDownloadConfig.moveNetLightning;

  final Queue<double> _ratioWindow = Queue<double>();

  FallDetectorState _state = const FallDetectorState();
  FallDetectorState get state => _state;

  CameraController? _cameraController;
  CameraController? get cameraController => _cameraController;

  StreamSubscription<MqttConnectionStatus>? _statusSubscription;
  DateTime? _lastEventAt;

  bool _busy = false;
  int _frameCounter = 0;

  Future<void> setup() async {
    final modelState = await _modelManager.refresh(modelConfig);
    _state = _state.copyWith(modelState: modelState);

    final granted = await _permissionService.requestCameraPermission();
    final ok = granted == AppPermissionStatus.granted;
    _state = _state.copyWith(permissionGranted: ok, error: ok ? null : '摄像头权限未授权');
    notifyListeners();

    if (!ok) return;

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _state = _state.copyWith(error: '未发现可用摄像头');
      notifyListeners();
      return;
    }

    final selected = cameras.firstWhere(
      (it) => it.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      selected,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _cameraController!.initialize();

    _state = _state.copyWith(cameraReady: true, error: null);
    notifyListeners();
  }

  Future<void> downloadModel() async {
    final state = await _modelManager.downloadModel(
      modelConfig,
      onProgress: (progressState) {
        _state = _state.copyWith(modelState: progressState, error: progressState.error);
        notifyListeners();
      },
    );
    _state = _state.copyWith(modelState: state, error: state.error);
    notifyListeners();
  }

  Future<void> loadModel() async {
    final state = await _modelManager.loadModel(modelConfig);
    _state = _state.copyWith(modelState: state, error: state.error);
    notifyListeners();
  }

  Future<void> deleteModel() async {
    final state = await _modelManager.deleteModel(modelConfig);
    _state = _state.copyWith(modelState: state, error: null);
    notifyListeners();
  }

  Future<void> startDetection({required String serialNumber}) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _state = _state.copyWith(error: '摄像头未就绪');
      notifyListeners();
      return;
    }

    if (_state.detecting) return;

    _ratioWindow.clear();

    await _cameraController!.startImageStream((image) async {
      if (_busy) return;
      _busy = true;
      try {
        _frameCounter += 1;
        if (_frameCounter % 5 != 0) return;

        final box = _detector.infer(
          image,
          interpreter: _modelManager.interpreter,
          inputSize: modelConfig.inputSize,
        );
        final inference = _classifyFall(box);

        _state = _state.copyWith(lastInference: inference, error: null);
        notifyListeners();

        final shouldPush = inference.isFallConfirmed ||
            (_state.statistics.totalSendCount % 30 == 0 && inference.isFallSuspected);

        if (_state.isConnected && shouldPush) {
          await _pushEvent(serialNumber, inference);
        }
      } finally {
        _busy = false;
      }
    });

    _state = _state.copyWith(detecting: true);
    notifyListeners();
  }

  Future<void> stopDetection() async {
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }
    _state = _state.copyWith(detecting: false);
    notifyListeners();
  }

  FallInferenceResult _classifyFall(DetectionBox box) {
    final now = DateTime.now();
    final ratio = box.aspectRatio;

    _ratioWindow.add(ratio);
    while (_ratioWindow.length > 12) {
      _ratioWindow.removeFirst();
    }

    final baseline = _ratioWindow.isEmpty ? ratio : _ratioWindow.first;
    final delta = ratio - baseline;

    final suspected = ratio > 0.85 && delta > 0.22;
    final confirmed = ratio > 1.00 && delta > 0.35 && box.confidence > 0.65;

    return FallInferenceResult(
      box: box,
      isFallSuspected: suspected,
      isFallConfirmed: confirmed,
      ratioDelta: delta,
      timestamp: now,
      modelName: _modelManager.interpreter != null ? modelConfig.name : 'fallback_proxy',
    );
  }

  Future<void> _pushEvent(String serialNumber, FallInferenceResult inference) async {
    final now = DateTime.now();
    if (_lastEventAt != null && now.difference(_lastEventAt!).inSeconds < 3) return;

    final type = inference.isFallConfirmed
        ? FallEventType.fallConfirmed
        : (inference.isFallSuspected ? FallEventType.fallAlert : FallEventType.monitoring);

    final payload = FallEventPayload(
      serialNumber: serialNumber,
      eventType: type,
      inference: inference,
    );

    final success = await _service.sendEvent(payload);
    if (!success) return;

    _lastEventAt = now;
    _state = _state.copyWith(
      statistics: _state.statistics.copyWith(
        totalSendCount: _state.statistics.totalSendCount + 1,
        fallEventCount:
            _state.statistics.fallEventCount + (type == FallEventType.fallConfirmed ? 1 : 0),
        lastSendTime: now,
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    stopDetection();
    _statusSubscription?.cancel();
    _cameraController?.dispose();
    _modelManager.dispose();
    super.dispose();
  }
}
