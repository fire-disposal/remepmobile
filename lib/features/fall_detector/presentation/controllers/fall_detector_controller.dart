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
    this.isSending = false,
    this.error,
    this.lastInference,
    this.statistics = const SendStatistics(),
    this.modelState = const ModelManagerState(),
  });

  final bool isConnected;
  final bool permissionGranted;
  final bool cameraReady;
  final bool detecting;
  final bool isSending;
  final String? error;
  final FallInferenceResult? lastInference;
  final SendStatistics statistics;
  final ModelManagerState modelState;

  FallDetectorState copyWith({
    bool? isConnected,
    bool? permissionGranted,
    bool? cameraReady,
    bool? detecting,
    bool? isSending,
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
      isSending: isSending ?? this.isSending,
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
  Timer? _autoSendTimer;
  bool _isAutoSendEnabled = false;

  bool get isAutoSendEnabled => _isAutoSendEnabled;

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

  Future<bool> sendFallEvent({
    required String serialNumber,
    required FallEventType eventType,
    required double confidence,
    bool autoTimestamp = true,
  }) async {
    _state = _state.copyWith(isSending: true);
    notifyListeners();

    final payload = FallEventPayload(
      serialNumber: serialNumber,
      eventType: eventType,
      inference: FallInferenceResult(
        box: DetectionBox(
          left: 0.2,
          top: 0.3,
          width: 0.4,
          height: 0.5,
          confidence: confidence.clamp(0.0, 1.0),
        ),
        isFallSuspected: eventType == FallEventType.fallAlert,
        isFallConfirmed: eventType == FallEventType.fallConfirmed || eventType == FallEventType.personFall,
        ratioDelta: 0.35,
        timestamp: autoTimestamp ? DateTime.now() : DateTime.now().toUtc(),
        modelName: 'simulator',
      ),
    );

    final success = await _service.sendEvent(payload);

    if (success) {
      _state = _state.copyWith(
        isSending: false,
        statistics: _state.statistics.copyWith(
          totalSendCount: _state.statistics.totalSendCount + 1,
          manualSendCount: _state.statistics.manualSendCount + 1,
          lastSendTime: DateTime.now(),
        ),
      );
    } else {
      _state = _state.copyWith(isSending: false, error: '发送失败');
    }
    notifyListeners();
    return success;
  }

  Future<bool> sendDeviceData({
    required String serialNumber,
    required DeviceType deviceType,
    bool autoTimestamp = true,
  }) async {
    _state = _state.copyWith(isSending: true);
    notifyListeners();

    final data = _generateMockData(deviceType);
    final message = DeviceDataMessage(
      deviceType: deviceType.value,
      timestamp: autoTimestamp ? DateTime.now().toUtc().toIso8601String() : null,
      data: data,
    );

    try {
      _mqttService.publish(
        topic: 'remipedia/$serialNumber/device',
        message: message.toJsonString(),
      );
      _state = _state.copyWith(
        isSending: false,
        statistics: _state.statistics.copyWith(
          totalSendCount: _state.statistics.totalSendCount + 1,
          manualSendCount: _state.statistics.manualSendCount + 1,
          lastSendTime: DateTime.now(),
        ),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(isSending: false, error: '发送失败: $e');
      notifyListeners();
      return false;
    }
  }

  void startAutoSend({
    required String serialNumber,
    required FallEventType eventType,
    required double confidence,
    required int intervalSeconds,
  }) {
    _isAutoSendEnabled = true;
    _autoSendTimer?.cancel();
    _autoSendTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      if (!_state.isConnected) return;
      final payload = FallEventPayload(
        serialNumber: serialNumber,
        eventType: eventType,
        inference: FallInferenceResult(
          box: DetectionBox(
            left: 0.2,
            top: 0.3,
            width: 0.4,
            height: 0.5,
            confidence: confidence.clamp(0.0, 1.0),
          ),
          isFallSuspected: eventType == FallEventType.fallAlert,
          isFallConfirmed: eventType == FallEventType.fallConfirmed || eventType == FallEventType.personFall,
          ratioDelta: 0.35,
          timestamp: DateTime.now(),
          modelName: 'simulator_auto',
        ),
      );
      final success = await _service.sendEvent(payload);
      if (success) {
        _state = _state.copyWith(
          statistics: _state.statistics.copyWith(
            totalSendCount: _state.statistics.totalSendCount + 1,
            autoSendCount: _state.statistics.autoSendCount + 1,
            lastSendTime: DateTime.now(),
          ),
        );
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void stopAutoSend() {
    _isAutoSendEnabled = false;
    _autoSendTimer?.cancel();
    _autoSendTimer = null;
    notifyListeners();
  }

  List<int> _generateMockData(DeviceType type) {
    switch (type) {
      case DeviceType.heartRateMonitor:
        return [72, 75, 78, 73, 76];
      case DeviceType.spo2Sensor:
        return [98, 97, 99, 98, 97];
      case DeviceType.smartWatch:
        return [8500, 72, 98, 120, 80];
      case DeviceType.fallDetector:
        return [10, 20, 30, 40, 50, 60];
    }
  }

  @override
  void dispose() {
    stopAutoSend();
    stopDetection();
    _statusSubscription?.cancel();
    _cameraController?.dispose();
    _modelManager.dispose();
    super.dispose();
  }
}
