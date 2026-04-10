import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/widgets/yolo_controller.dart';

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

  final YOLOViewController _yoloController = YOLOViewController();

  bool _isInitializing = false;
  bool _isStreaming = false;
  bool _isModelLoading = false;
  bool _hasAppliedProfile = false;
  bool _isModelReady = false;
  String _modelStatusMessage = '未检测模型';
  String? _resolvedModelPath;
  CancelToken? _downloadCancelToken;
  bool _preferDownloadedModel = true;
  AlgorithmParams _customAlgorithmParams = AlgorithmParams.defaultFor(_fixedAlgorithm);

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
  DateTime? _lastEventLogAt;
  int? _lastDetectionCount;
  bool? _lastFallAlarmState;
  DateTime? _lastRuntimeLogAt;
  final List<VisionEvent> _runtimeLogs = [];

  YOLOStreamingConfig _activeStreamingConfig = const YOLOStreamingConfig.minimal();

  // 模型状态（支持下载）
  ModelRuntimeState _modelState = const ModelRuntimeState(
    manifest: ModelManifest(
      type: _fixedModel,
      fileName: 'yolo11n_int8.tflite',
      downloadUrl: 'https://github.com/ultralytics/yolo-flutter-app/releases/download/v0.2.0/yolo11n_int8.tflite',
      sizeLabel: '约4MB',
      builtIn: true,
      format: ModelFormat.tflite,
    ),
    isDownloaded: false,
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
  YOLOViewController get yoloController => _yoloController;
  YOLOStreamingConfig get streamingConfig => _activeStreamingConfig;
  List<VisionEvent> get runtimeLogs => List.unmodifiable(_runtimeLogs);

  bool get isModelReady => _isModelReady;
  String get modelStatusMessage => _modelStatusMessage;
  String get yoloModelPath => _resolvedModelPath ?? 'assets/models/yolo11n_int8.tflite';
  bool get canDownloadModel => _modelState.manifest.hasDownloadUrl;
  bool get preferDownloadedModel => _preferDownloadedModel;

  /// 获取当前算法参数
  AlgorithmParams get algorithmParams => _customAlgorithmParams;

  Future<void> initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;
    notifyListeners();

    try {
      await refreshPermission();

      _isModelLoading = true;
      _modelStatusMessage = '正在校验模型资源...';
      notifyListeners();

      await _resolveModelPath();
      await _verifyModelAsset();
      _isModelLoading = false;
      notifyListeners();

      // 初始化 YOLO 控制器配置
      _activeStreamingConfig = _buildStreamingConfig();
      await _applyStreamingProfile();

      _latestEvent = VisionEvent(
        title: 'YOLO 检测已就绪',
        detail: '使用 YOLO11n Detect 模型进行目标检测。',
        timestamp: DateTime.now(),
        level: VisionEventLevel.success,
      );
      _pushRuntimeLog('初始化完成', _modelStatusMessage, force: true);
    } catch (e) {
      AppLogger.error('Initialization error: $e');
      _pushRuntimeLog('初始化失败', e.toString(), level: VisionEventLevel.error, force: true);
    } finally {
      _isInitializing = false;
      _isModelLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshPermission() async {
    final granted = await _permissionService.checkModulePermissions(AppModule.visionDetection);
    _permissionState = granted 
        ? VisionPermissionState.granted 
        : VisionPermissionState.denied;
    notifyListeners();
  }

  Future<void> requestPermission() async {
    final result = await _permissionService.requestModulePermissions(AppModule.visionDetection);
    final granted = result.values.every((s) => s == AppPermissionStatus.granted);
    _permissionState = granted 
        ? VisionPermissionState.granted 
        : VisionPermissionState.denied;
    notifyListeners();
  }

  Future<void> requestPermissions() => requestPermission();

  Future<void> openSystemSettings() => _permissionService.openExternalAppSettings();

  void setDetectionMode(VisionDetectionMode mode) {
    if (_detectionMode == mode) return;
    _detectionMode = mode;
    _hasAppliedProfile = false;
    _latestEvent = VisionEvent(
      title: '识别模式已切换',
      detail: '当前模式：${mode.label} - ${mode.description}',
      timestamp: DateTime.now(),
      level: VisionEventLevel.success,
    );
    if (_isStreaming) {
      unawaited(_applyStreamingProfile());
    } else {
      _activeStreamingConfig = _buildStreamingConfig();
    }
    notifyListeners();
  }

  void updateAlgorithmParams(AlgorithmParams params) {
    _customAlgorithmParams = params;
    _latestEvent = VisionEvent(
      title: '算法参数已更新',
      detail: 'aspect=${params.aspectRatioThreshold.toStringAsFixed(2)}，speed=${params.verticalSpeedThreshold.toStringAsFixed(2)}',
      timestamp: DateTime.now(),
      level: VisionEventLevel.success,
    );
    _pushRuntimeLog('算法参数', _latestEvent!.detail, force: true);
    notifyListeners();
  }

  void resetAlgorithmParams() {
    _customAlgorithmParams = AlgorithmParams.defaultFor(_fixedAlgorithm);
    _latestEvent = VisionEvent(
      title: '算法参数已重置',
      detail: '已恢复默认阈值配置。',
      timestamp: DateTime.now(),
      level: VisionEventLevel.info,
    );
    _pushRuntimeLog('算法参数', _latestEvent!.detail, force: true);
    notifyListeners();
  }

  Future<void> setPreferDownloadedModel(bool prefer) async {
    _preferDownloadedModel = prefer;
    await _resolveModelPath();
    await _verifyModelAsset();
    notifyListeners();
  }

  Future<void> toggleStreaming() async {
    if (_permissionState != VisionPermissionState.granted) {
      await requestPermission();
      if (_permissionState != VisionPermissionState.granted) return;
    }

    _isStreaming = !_isStreaming;
    _hasAppliedProfile = false;
    _lastEventLogAt = null;
    _lastDetectionCount = null;
    _lastFallAlarmState = null;
    _lastRuntimeLogAt = null;
    _runtimeLogs.clear();
    _detections = [];
    _inferenceFps = 0;
    _processingLatencyMs = 0;
    
    if (_isStreaming) {
      await _applyStreamingProfile();
      await _yoloController.restartCamera();
      _pushRuntimeLog('识别流启动', '开始接收相机画面并进行推理。', force: true);
    } else {
      await _yoloController.stop();
      _pushRuntimeLog('识别流停止', '推理已停止。', force: true);
    }

    _latestEvent = VisionEvent(
      title: _isStreaming ? '识别流已启动' : '识别流已停止',
      detail: _isStreaming ? '正在接收相机数据并进行推理...' : '已停止所有推理任务。',
      timestamp: DateTime.now(),
      level: _isStreaming ? VisionEventLevel.success : VisionEventLevel.info,
    );
    
    notifyListeners();
  }

  /// 处理来自 YOLO SDK 的检测结果
  void onYoloResult(List<YOLOResult> results) {
    if (!_isStreaming) return;
    if (!_hasAppliedProfile) {
      unawaited(_applyStreamingProfile());
    }

    final now = DateTime.now();
    _detections = results
        .where((result) {
          final name = result.className.toLowerCase();
          return name == 'person' || name == '0' || result.classIndex == 0;
        })
        .map((result) {
          final rect = result.normalizedBox;
          return DetectionBox(
            normalizedRect: Rect.fromLTRB(
              rect.left.clamp(0.0, 1.0),
              rect.top.clamp(0.0, 1.0),
              rect.right.clamp(0.0, 1.0),
              rect.bottom.clamp(0.0, 1.0),
            ),
            label: result.className,
            confidence: result.confidence,
          );
        })
        .toList(growable: false);

    final double maxConfidence = _detections.isEmpty
        ? 0
        : _detections.map((item) => item.confidence).reduce((a, b) => a > b ? a : b);
    final totalResults = results.length;
    final labelPreview = results
      .map((item) => '${item.className}#${item.classIndex}')
        .toSet()
        .take(4)
        .join(',');
    _pushRuntimeLog(
      '推理结果',
      'total=$totalResults, person=${_detections.length}, maxConf=${maxConfidence.toStringAsFixed(2)}, labels=[$labelPreview], fps=$_inferenceFps, latency=${_processingLatencyMs}ms',
    );
    
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

    final shouldLog = _shouldLogEvent(now, _detections.length, _fallAlarmOn);
    if (shouldLog) {
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
      _lastEventLogAt = now;
      _lastDetectionCount = _detections.length;
      _lastFallAlarmState = _fallAlarmOn;
    }

    notifyListeners();
  }

  /// 处理性能指标
  void onYoloPerformanceMetrics(YOLOPerformanceMetrics metrics) {
    if (!_isStreaming) return;
    _fps = metrics.fps.round();
    _inferenceFps = _fps;
    _processingLatencyMs = metrics.processingTimeMs.round();
    notifyListeners();
  }

  void _pushRuntimeLog(
    String title,
    String detail, {
    VisionEventLevel level = VisionEventLevel.info,
    bool force = false,
  }) {
    final now = DateTime.now();
    if (!force && _lastRuntimeLogAt != null) {
      if (now.difference(_lastRuntimeLogAt!) < const Duration(milliseconds: 250)) {
        return;
      }
    }
    _lastRuntimeLogAt = now;
    _runtimeLogs.insert(
      0,
      VisionEvent(
        title: title,
        detail: detail,
        timestamp: now,
        level: level,
      ),
    );
    if (_runtimeLogs.length > 30) {
      _runtimeLogs.removeRange(30, _runtimeLogs.length);
    }
    notifyListeners();
  }

  Future<void> _verifyModelAsset() async {
    try {
      if (_resolvedModelPath != null) {
        final file = File(_resolvedModelPath!);
        final size = await file.length();
        _isModelReady = size > 0;
        _modelStatusMessage = _isModelReady
            ? '模型就绪（本地缓存）：${_modelState.manifest.fileName} (${(size / 1024 / 1024).toStringAsFixed(2)} MB)'
            : '模型文件为空：${_modelState.manifest.fileName}';
        _pushRuntimeLog('模型状态', _modelStatusMessage, force: true);
        return;
      }

      final data = await rootBundle.load(yoloModelPath);
      _isModelReady = data.lengthInBytes > 0;
      _modelStatusMessage = _isModelReady
          ? '模型就绪（内置）：${yoloModelPath} (${(data.lengthInBytes / 1024).toStringAsFixed(1)} KB)'
          : '模型文件为空：${yoloModelPath}';
      _pushRuntimeLog('模型状态', _modelStatusMessage, force: true);
    } catch (e) {
      _isModelReady = false;
      _modelStatusMessage = '模型资源未找到：${yoloModelPath}';
      _pushRuntimeLog('模型状态', _modelStatusMessage, level: VisionEventLevel.error, force: true);
      AppLogger.error('Model asset load failed: $e');
    }
  }

  bool _shouldLogEvent(DateTime now, int detectionCount, bool fallAlarmOn) {
    if (_lastEventLogAt == null) return true;
    final elapsed = now.difference(_lastEventLogAt!);
    final countChanged = _lastDetectionCount != detectionCount;
    final alarmChanged = _lastFallAlarmState != fallAlarmOn;
    return alarmChanged || countChanged || elapsed.inMilliseconds >= 1000;
  }

  YOLOStreamingConfig _buildStreamingConfig() {
    return switch (_detectionMode) {
      VisionDetectionMode.performance => YOLOStreamingConfig.highPerformance(inferenceFrequency: 30),
      VisionDetectionMode.sensitive => const YOLOStreamingConfig.full(),
      VisionDetectionMode.balanced => YOLOStreamingConfig.throttled(maxFPS: 24),
    };
  }

  Future<void> _applyStreamingProfile() async {
    _activeStreamingConfig = _buildStreamingConfig();
    if (!_yoloController.isInitialized) {
      return;
    }
    final confidence = switch (_detectionMode) {
      VisionDetectionMode.performance => 0.35,
      VisionDetectionMode.balanced => 0.25,
      VisionDetectionMode.sensitive => 0.2,
    };
    final iou = switch (_detectionMode) {
      VisionDetectionMode.performance => 0.55,
      VisionDetectionMode.balanced => 0.5,
      VisionDetectionMode.sensitive => 0.45,
    };
    final maxItems = switch (_detectionMode) {
      VisionDetectionMode.performance => 15,
      VisionDetectionMode.balanced => 25,
      VisionDetectionMode.sensitive => 40,
    };

    await _yoloController.setThresholds(
      confidenceThreshold: confidence,
      iouThreshold: iou,
      numItemsThreshold: maxItems,
    );
    await _yoloController.setStreamingConfig(_activeStreamingConfig);
    await _yoloController.setShowOverlays(false);
    await _yoloController.setShowUIControls(false);
    _hasAppliedProfile = true;
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
    _downloadCancelToken?.cancel();
    super.dispose();
  }

  Future<void> downloadModel() async {
    if (!canDownloadModel) return;
    if (_modelState.isDownloading) return;
    final url = _modelState.manifest.allUrls.first;

    _isModelLoading = true;
    _modelState = _modelState.copyWith(isDownloading: true, progress: 0);
    _modelStatusMessage = '正在下载模型...';
    _pushRuntimeLog('模型下载', '开始下载 ${_modelState.manifest.fileName}', force: true);
    notifyListeners();

    try {
      final targetPath = await _getModelFilePath();
      _downloadCancelToken = CancelToken();
      final dio = Dio();
      await dio.download(
        url,
        targetPath,
        cancelToken: _downloadCancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final progress = received / total;
          _modelState = _modelState.copyWith(progress: progress);
          notifyListeners();
        },
      );

      _modelState = _modelState.copyWith(isDownloaded: true, isDownloading: false, progress: 1);
      _resolvedModelPath = targetPath;
      _preferDownloadedModel = true;
      _isModelReady = true;
      _modelStatusMessage = '模型已下载：${_modelState.manifest.fileName}';
      _pushRuntimeLog('模型下载', _modelStatusMessage, force: true);
    } catch (e) {
      _modelState = _modelState.copyWith(isDownloading: false);
      _modelStatusMessage = '模型下载失败：$e';
      _pushRuntimeLog('模型下载失败', e.toString(), level: VisionEventLevel.error, force: true);
    } finally {
      _isModelLoading = false;
      notifyListeners();
    }
  }

  Future<void> _resolveModelPath() async {
    final targetPath = await _getModelFilePath();
    final file = File(targetPath);
    if (_preferDownloadedModel && await file.exists()) {
      _resolvedModelPath = targetPath;
      _modelState = _modelState.copyWith(isDownloaded: true);
      _isModelReady = true;
      _modelStatusMessage = '模型已就绪（本地缓存）';
    } else {
      _resolvedModelPath = null;
      _modelState = _modelState.copyWith(isDownloaded: false);
      _isModelReady = false;
      _modelStatusMessage = _preferDownloadedModel
          ? '未检测到本地模型，请下载'
          : '当前使用内置模型';
    }
  }

  Future<String> _getModelFilePath() async {
    final dir = await getApplicationSupportDirectory();
    final modelDir = Directory('${dir.path}${Platform.pathSeparator}models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return '${modelDir.path}${Platform.pathSeparator}${_modelState.manifest.fileName}';
  }
}
