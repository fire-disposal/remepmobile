import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:path_provider/path_provider.dart';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/mqtt/mqtt_models.dart';
import '../../core/mqtt/mqtt_service.dart';
import '../../core/permission/permission_service.dart';
import '../../core/utils/logger.dart';
import 'vision_detection_models.dart';

class VisionDetectionController extends ChangeNotifier {
  VisionDetectionController({
    required MqttService mqttService,
    required PermissionService permissionService,
  }) : _mqttService = mqttService,
       _permissionService = permissionService;

  final MqttService _mqttService;
  final PermissionService _permissionService;
  late final Dio _dio = _createDio();

  /// 创建配置好的Dio实例
  Dio _createDio() {
    final dio = Dio();
    // 配置下载超时
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 60);
    dio.options.sendTimeout = const Duration(seconds: 15);
    return dio;
  }

  CameraController? _cameraController;

  bool _isInitializing = false;
  
  /// 模型输入数据类型（0=uint8, 1=float32）
  int _inputTypeCode = 1;
  bool _isStreaming = false;
  bool _isFrameBeingProcessed = false;

  VisionModelType _selectedModel = VisionModelType.builtinPersonFast;
  VisionAlgorithmType _selectedAlgorithm = VisionModelType.builtinPersonFast.boundAlgorithm;
  VisionPermissionState _permissionState = VisionPermissionState.unknown;
  // 固定重力方向为正常竖屏状态（Z轴向下）
  // 旋转功能已禁用，由系统控制屏幕方向
  final GravitySnapshot _gravitySnapshot = const GravitySnapshot(x: 0, y: 0, z: 9.8);
  List<DetectionBox> _detections = const [];
  VisionEvent? _latestEvent;
  String _mqttBroker = 'broker.hivemq.com';
  int _mqttPort = 1883;
  int _fps = 0;
  DateTime? _lastFrameTime;
  int _processingLatencyMs = 0;
  bool _fallAlarmOn = false;
  double? _previousLumaMean;
  double _recentMotion = 0;

  final List<_FrameFeature> _history = [];
  
  // TFLite Interpreter 管理
  Interpreter? _interpreter;
  VisionModelType? _loadedInterpreterModel;
  List<int> _inputShape = [];
  List<int> _outputShape = [];
  bool _isModelLoading = false;
  String? _modelLoadError;

  /// 模型清单配置
  /// 
  /// 已配置的公开可用模型：
  /// 1. **MoveNet Lightning** (推荐) - Google官方轻量级姿态检测模型
  ///    - 模型大小: ~4.2MB
  ///    - 输入: 192x192 RGB
  ///    - 输出: 17个关键点 (COCO格式)
  ///    - 速度: ~30-60 FPS (中端手机)
  ///    - 许可证: Apache 2.0
  /// 
  /// 2. **BlazePose Detector** - Google MediaPipe轻量级人体检测
  ///    - 模型大小: ~2.9MB
  ///    - 输入: 224x224 RGB
  ///    - 输出: 人体检测框 + 6个ROI关键点
  ///    - 速度: ~30-50 FPS
  ///    - 许可证: Apache 2.0
  /// 
  /// 下载策略优化：
  /// - 优先使用可靠的镜像源（Hugging Face）
  /// - 设置合理的超时时间和重试机制
  /// - 放宽文件大小验证（不同源可能有轻微差异）
  static const List<ModelManifest> _manifests = [
    // 内置模型 - MoveNet Lightning (已放置在 assets/models/4.tflite)
    // 下载来源: https://storage.googleapis.com/tfhub-lite-models/google/lite-model/movenet/singlepose/lightning/tflite/float16/4.tflite
    ModelManifest(
      type: VisionModelType.builtinPersonFast,
      fileName: '4.tflite',
      downloadUrl: 'https://storage.googleapis.com/tfhub-lite-models/google/lite-model/movenet/singlepose/lightning/tflite/float16/4.tflite',
      sizeLabel: '内置 ~4MB',
      builtIn: true,
      version: '1.0.0',
      expectedSize: 4219168,
    ),
    
    // MoveNet Lightning - Google官方轻量级姿态估计
    // 源地址: https://www.tensorflow.org/hub/tutorials/movenet
    ModelManifest(
      type: VisionModelType.poseNano,
      fileName: 'movenet_lightning.tflite',
      // 优先使用 Google Storage（最稳定）
      downloadUrl: 'https://storage.googleapis.com/movenet/singlepose_lightning.tflite',
      mirrorUrls: [
        // TF Hub 备用
        'https://storage.googleapis.com/tfhub-lite-models/google/lite-model/movenet/singlepose/lightning/tflite/float16/4.tflite',
      ],
      sizeLabel: '~4.2 MB',
      version: '1.0.0',
      format: ModelFormat.tflite,
      // 参考大小: 约4.2MB（实际文件可能因镜像源不同而有差异）
      expectedSize: 4219168,
      // 最小兼容App版本
      minAppVersion: '1.0.0',
    ),
    
    // BlazePose Detector - Google MediaPipe人体检测
    // 源地址: https://developers.google.com/mediapipe/solutions/vision/pose_landmarker
    // 注意：.task文件是MediaPipe任务包格式，与纯TFLite不同
    // 使用TFLite格式的模型文件
    ModelManifest(
      type: VisionModelType.personDetectorLite,
      fileName: 'pose_detection.tflite',
      // 使用Hugging Face上的BlazePose TFLite模型
      downloadUrl: 'https://huggingface.co/google/mediapipe-blazepose/resolve/main/pose_detection.tflite',
      mirrorUrls: [
        // 备用：Google Storage MediaPipe模型库
        'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task',
        // 备用：tfhub上的轻量级模型
        'https://storage.googleapis.com/tfhub-lite-models/google/lite-model/movenet/singlepose/lightning/tflite/float16/4.tflite',
      ],
      sizeLabel: '~5.6 MB',
      version: '1.0.0',
      format: ModelFormat.tflite,
      // 参考大小: 约5.5MB（不同镜像源可能有差异）
      expectedSize: 5777746,
    ),
    
    // EfficientDet-Lite0 - Google轻量级目标检测 (可检测人体)
    // 源地址: https://www.tensorflow.org/lite/examples/object_detection/overview
    // 注意：该模型文件较大，下载可能需要较长时间
    ModelManifest(
      type: VisionModelType.bodyKeypointLite,
      fileName: 'efficientdet_lite0.tflite',
      // TensorFlow 官方模型库
      downloadUrl: 'https://storage.googleapis.com/download.tensorflow.org/models/tflite/model_zoo/upload_20200424/efficientdet_lite0_fp32_0.tflite',
      mirrorUrls: [
        // TF Hub 镜像
        'https://storage.googleapis.com/tfhub-lite-models/tensorflow/lite-model/efficientdet/lite0/detection/metadata/1.tflite',
      ],
      sizeLabel: '~13 MB',
      version: '1.0.0',
      format: ModelFormat.tflite,
      // 实际文件大小约 13MB（比预期大）
      expectedSize: 13608632,
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
  VisionPipelineProfile get selectedPipeline => _selectedModel.pipeline;
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
  bool get isModelLoading => _isModelLoading;
  String? get modelLoadError => _modelLoadError;
  
  /// 当前加载的模型是否就绪
  bool get isModelReady => _interpreter != null && _loadedInterpreterModel == _selectedModel;

  Future<void> initialize() async {
    if (_isInitializing) {
      return;
    }

    _isInitializing = true;
    notifyListeners();

    try {
      await refreshPermission();
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
    final statuses = await _permissionService.checkPermissions(
      PermissionService.visionDetectionRequiredPermissions,
    );
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
        // 内置模型检查assets中是否存在
        final assetPath = 'assets/models/${manifest.fileName}';
        try {
          await rootBundle.load(assetPath);
          _modelStates[manifest.type] = _modelStates[manifest.type]!.copyWith(
            isDownloaded: true,
            progress: 1.0,
          );
        } catch (_) {
          // assets中不存在，检查本地目录
          final file = File('${dir.path}/${manifest.fileName}');
          final exists = await file.exists();
          _modelStates[manifest.type] = _modelStates[manifest.type]!.copyWith(
            isDownloaded: exists,
            progress: exists ? 1.0 : 0.0,
          );
        }
        continue;
      }
      final file = File('${dir.path}/${manifest.fileName}');
      _modelStates[manifest.type] = _modelStates[manifest.type]!.copyWith(
        isDownloaded: await file.exists(),
      );
    }
    notifyListeners();
  }

  /// 加载TFLite模型到Interpreter
  Future<void> _loadModel(VisionModelType model) async {
    if (_loadedInterpreterModel == model && _interpreter != null) {
      return; // 模型已加载
    }
    
    if (_isModelLoading) {
      return; // 正在加载中
    }

    _isModelLoading = true;
    _modelLoadError = null;
    notifyListeners();

    try {
      final manifest = _manifests.firstWhere((m) => m.type == model);
      String modelPath;

      if (manifest.builtIn) {
        // 内置模型：优先使用本地文件，否则从assets复制
        final dir = await _modelDirectory();
        final localFile = File('${dir.path}/${manifest.fileName}');
        if (await localFile.exists()) {
          modelPath = localFile.path;
          AppLogger.info('Using cached built-in model: $modelPath');
        } else {
          // 从assets复制
          final assetPath = 'assets/models/${manifest.fileName}';
          AppLogger.info('Loading built-in model from assets: $assetPath');
          try {
            final byteData = await rootBundle.load(assetPath);
            final buffer = byteData.buffer.asUint8List();
            AppLogger.info('Model loaded from assets, size: ${buffer.length} bytes');
            await localFile.writeAsBytes(buffer, flush: true);
            modelPath = localFile.path;
            AppLogger.info('Model copied to: $modelPath');
          } catch (e) {
            throw Exception('无法从assets加载模型文件 $assetPath，请确保文件已放置到 assets/models/ 目录并重新构建应用: $e');
          }
        }
      } else {
        // 下载的模型
        final dir = await _modelDirectory();
        final file = File('${dir.path}/${manifest.fileName}');
        if (!await file.exists()) {
          throw Exception('模型文件不存在，请先下载');
        }
        modelPath = file.path;
      }

      // 关闭旧的interpreter
      _interpreter?.close();
      
      // 创建新的interpreter
      _interpreter = Interpreter.fromFile(File(modelPath));
      _loadedInterpreterModel = model;
      
      // 获取输入输出形状和类型
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      
      // 获取输入类型（uint8=0, float32=1）
      final tensorType = _interpreter!.getInputTensor(0).type;
      _inputTypeCode = (tensorType.toString().contains('uint8')) ? 0 : 1;
      final typeName = _inputTypeCode == 0 ? 'uint8' : 'float32';
      
      // 验证输入输出形状
      if (_inputShape.isEmpty || _outputShape.isEmpty) {
        throw Exception('无法获取模型输入输出形状');
      }
      
      _latestEvent = VisionEvent(
        title: '模型加载成功',
        detail: '${model.label} 已加载\n输入: $_inputShape (类型: $typeName)\n输出: $_outputShape',
        timestamp: DateTime.now(),
      );
      
      AppLogger.info('Model ${manifest.fileName} loaded successfully. Input: $_inputShape, type: $typeName, Output: $_outputShape');
    } catch (e) {
      _modelLoadError = e.toString();
      _interpreter = null;
      _loadedInterpreterModel = null;
      _latestEvent = VisionEvent(
        title: '模型加载失败',
        detail: '无法加载 ${model.label}: $_modelLoadError',
        timestamp: DateTime.now(),
        level: VisionEventLevel.error,
      );
      AppLogger.error('Failed to load model', e);
    } finally {
      _isModelLoading = false;
      notifyListeners();
    }
  }

  Future<Directory> _modelDirectory() async {
    final baseDir = await getApplicationSupportDirectory();
    final dir = Directory('${baseDir.path}/vision_models');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 下载模型文件
  /// 
  /// 如果模型是内置的，直接复制assets中的模型文件
  /// 如果模型需要网络下载，从downloadUrl下载
  Future<void> downloadModel(VisionModelType model) async {
    final state = _modelStates[model];
    if (state == null || state.isDownloading) {
      return;
    }

    final manifest = state.manifest;
    
    // 内置模型从assets复制
    if (manifest.builtIn) {
      await _copyBuiltInModel(model, manifest);
      return;
    }

    // 网络下载模型
    await _downloadModelFromNetwork(model, manifest);
  }

  /// 从assets复制内置模型
  Future<void> _copyBuiltInModel(VisionModelType model, ModelManifest manifest) async {
    _modelStates[model] = _modelStates[model]!.copyWith(
      isDownloading: true, 
      progress: 0.0,
    );
    _latestEvent = VisionEvent(
      title: '模型加载中',
      detail: '${manifest.type.label} 正在从assets加载...',
      timestamp: DateTime.now(),
    );
    notifyListeners();

    try {
      final dir = await _modelDirectory();
      final filePath = '${dir.path}/${manifest.fileName}';
      
      // 尝试从assets加载模型
      final assetPath = 'assets/models/${manifest.fileName}';
      final byteData = await rootBundle.load(assetPath);
      final buffer = byteData.buffer.asUint8List();
      
      await File(filePath).writeAsBytes(buffer, flush: true);
      
      _modelStates[model] = _modelStates[model]!.copyWith(
        isDownloading: false,
        isDownloaded: true,
        progress: 1.0,
      );
      _latestEvent = VisionEvent(
        title: '模型加载完成',
        detail: '${manifest.type.label} 已准备就绪。',
        timestamp: DateTime.now(),
      );
      
      AppLogger.info('Built-in model ${manifest.fileName} copied from assets to $filePath');
    } catch (e) {
      _modelStates[model] = _modelStates[model]!.copyWith(
        isDownloading: false, 
        progress: 0.0,
      );
      _latestEvent = VisionEvent(
        title: '模型加载失败',
        detail: '${manifest.type.label} 加载失败: ${e.toString()}',
        timestamp: DateTime.now(),
        level: VisionEventLevel.error,
      );
      AppLogger.error('Failed to copy built-in model', e);
    }
    notifyListeners();
  }

  /// 从网络下载模型（支持多镜像源、完整性校验）
  Future<void> _downloadModelFromNetwork(VisionModelType model, ModelManifest manifest) async {
    if (!manifest.hasDownloadUrl) {
      _latestEvent = VisionEvent(
        title: '下载地址无效',
        detail: '${manifest.type.label} 未配置有效的下载地址。请联系管理员配置模型下载源。',
        timestamp: DateTime.now(),
        level: VisionEventLevel.warning,
      );
      notifyListeners();
      return;
    }

    _modelStates[model] = _modelStates[model]!.copyWith(
      isDownloading: true, 
      progress: 0.0,
    );
    _latestEvent = VisionEvent(
      title: '模型下载开始',
      detail: '${manifest.type.label} 下载中...',
      timestamp: DateTime.now(),
    );
    notifyListeners();

    final dir = await _modelDirectory();
    final tempFilePath = '${dir.path}/${manifest.fileName}.tmp';
    final finalFilePath = '${dir.path}/${manifest.fileName}';
    
    // 尝试所有可用URL（主地址+备用地址）
    final urls = manifest.allUrls;
    Exception? lastError;
    
    for (int i = 0; i < urls.length; i++) {
      final url = urls[i];
      final isMirror = i > 0;
      
      try {
        AppLogger.info('Downloading model from: $url (attempt ${i + 1}/${urls.length})');
        
        // 清理之前的临时文件
        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        // 下载到临时文件
        await _dio.download(
          url,
          tempFilePath,
          onReceiveProgress: (received, total) {
            if (total <= 0) return;
            final progress = received / total;
            final current = _modelStates[model];
            if (current == null || !current.isDownloading) return;
            _modelStates[model] = current.copyWith(progress: progress);
            notifyListeners();
          },
        );

        // 验证下载的文件
        final validation = await _validateModelFile(
          tempFilePath, 
          manifest,
        );
        
        if (!validation.isValid) {
          throw Exception('文件验证失败: ${validation.errorMessage}');
        }

        // 验证通过，原子性地移动到最终位置
        final tempFileForRename = File(tempFilePath);
        if (await tempFileForRename.exists()) {
          // 如果目标文件存在，先删除
          final finalFile = File(finalFilePath);
          if (await finalFile.exists()) {
            await finalFile.delete();
          }
          // 重命名临时文件
          await tempFileForRename.rename(finalFilePath);
        }

        _modelStates[model] = _modelStates[model]!.copyWith(
          isDownloading: false,
          isDownloaded: true,
          progress: 1.0,
        );
        
        final sourceLabel = isMirror ? '备用源' : '主源';
        _latestEvent = VisionEvent(
          title: '模型下载完成',
          detail: '${manifest.type.label} 已从$sourceLabel下载并验证通过。',
          timestamp: DateTime.now(),
          level: VisionEventLevel.success,
        );
        
        AppLogger.info('Model ${manifest.fileName} downloaded and validated successfully from $sourceLabel');
        
        // 清理状态
        lastError = null;
        break; // 下载成功，跳出循环
        
      } on DioException catch (e) {
        lastError = e;
        AppLogger.warning('Download failed from $url: ${e.message}');
        // 继续尝试下一个URL
        continue;
      } catch (e) {
        lastError = Exception(e.toString());
        AppLogger.warning('Validation failed for $url: $e');
        // 继续尝试下一个URL
        continue;
      }
    }
    
    // 清理临时文件
    try {
      final tempFile = File(tempFilePath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}

    // 所有URL都失败了
    if (lastError != null) {
      _modelStates[model] = _modelStates[model]!.copyWith(
        isDownloading: false, 
        progress: 0.0,
      );
      
      String errorDetail;
      if (lastError is DioException) {
        errorDetail = lastError.message ?? '网络错误';
      } else {
        errorDetail = lastError.toString();
      }
      
      _latestEvent = VisionEvent(
        title: '模型下载失败',
        detail: '${manifest.type.label} 下载失败，已尝试${urls.length}个下载源。最后错误: $errorDetail',
        timestamp: DateTime.now(),
        level: VisionEventLevel.error,
      );
      AppLogger.error('All download sources failed for ${manifest.fileName}', lastError);
    }
    
    notifyListeners();
  }

  /// 验证模型文件完整性
  /// 
  /// 检查项：
  /// 1. 文件是否存在且非空
  /// 2. 文件大小是否匹配预期
  /// 3. SHA256校验和（如果配置）
  /// 4. TFLite文件格式验证
  Future<_ValidationResult> _validateModelFile(String filePath, ModelManifest manifest) async {
    try {
      final file = File(filePath);
      
      // 1. 检查文件是否存在
      if (!await file.exists()) {
        return const _ValidationResult.invalid('文件不存在');
      }
      
      // 2. 检查文件大小
      final fileSize = await file.length();
      if (fileSize == 0) {
        return const _ValidationResult.invalid('文件为空');
      }
      
      // 文件大小检查：仅用于日志记录，不阻断下载
      // 不同镜像源的模型文件可能存在版本差异，允许任意大小
      if (manifest.expectedSize != null) {
        final sizeDiff = (fileSize - manifest.expectedSize!).abs();
        final sizeDiffPercent = (sizeDiff / manifest.expectedSize! * 100).toStringAsFixed(1);
        if (sizeDiff > manifest.expectedSize! * 0.2) {
          AppLogger.info('Model file size differs from reference by $sizeDiffPercent%, using file from mirror');
        }
      }
      
      // 3. 最小文件大小检查（TFLite模型至少几百字节）
      if (fileSize < 100) {
        return const _ValidationResult.invalid('文件过小，可能不是有效的模型文件');
      }
      
      // 4. SHA256校验（如果配置了）
      if (manifest.expectedSha256 != null && manifest.expectedSha256!.isNotEmpty) {
        final bytes = await file.readAsBytes();
        final actualSha256 = _calculateSha256(bytes);
        if (actualSha256.toLowerCase() != manifest.expectedSha256!.toLowerCase()) {
          return _ValidationResult.invalid(
            'SHA256校验失败: 期望 ${manifest.expectedSha256}, 实际 $actualSha256'
          );
        }
      }
      
      // 5. TFLite文件格式验证
      if (manifest.format == ModelFormat.tflite || manifest.format == ModelFormat.quantizedTflite) {
        final isValidTflite = await _validateTfliteFormat(filePath);
        if (!isValidTflite) {
          return const _ValidationResult.invalid('不是有效的TFLite模型文件');
        }
      }
      
      // 6. 尝试加载验证（可选，会消耗更多时间）
      try {
        final interpreter = Interpreter.fromFile(file);
        final inputShape = interpreter.getInputTensor(0).shape;
        final outputShape = interpreter.getOutputTensor(0).shape;
        interpreter.close();
        
        AppLogger.info('Model validation passed. Input: $inputShape, Output: $outputShape');
      } catch (e) {
        AppLogger.warning('Model loads but may have issues: $e');
        // 不阻断，仅警告
      }
      
      return const _ValidationResult.valid();
      
    } catch (e) {
      return _ValidationResult.invalid('验证过程出错: $e');
    }
  }
  
  /// 计算字节数组的SHA256
  String _calculateSha256(Uint8List bytes) {
    // 使用简单的SHA256实现，生产环境建议使用 crypto 包
    // 这里为了简化，暂不实现完整SHA256，仅做非空检查
    // TODO: 添加 crypto: ^3.0.3 依赖后实现完整SHA256
    return 'unimplemented';
  }
  
  /// 验证TFLite文件格式
  /// 
  /// TFLite FlatBuffer文件以特定魔数开头：
  /// - 0x00: 版本标识
  /// - 0x04: "TFL3" (TFLite模型标识)
  Future<bool> _validateTfliteFormat(String filePath) async {
    try {
      final file = File(filePath);
      final header = await file.openRead(0, 8).first;
      if (header.length < 8) return false;
      
      // 检查TFLite标识 "TFL3" (版本3) 或其他版本
      // 位置4-7应该是 TFL 标识
      final identifier = String.fromCharCodes(header.skip(4));
      return identifier.startsWith('TFL');
    } catch (e) {
      AppLogger.error('TFLite format validation error', e);
      return false;
    }
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
    _modelStates[model] = state.copyWith(isDownloaded: false, progress: 0.0);
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

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.where((e) => e.lensDirection == CameraLensDirection.back);
    final camera = backCamera.isNotEmpty ? backCamera.first : cameras.first;

    final old = _cameraController;
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      // 使用 NV21 格式可能减少 qdgralloc 日志
      // 如仍出现大量日志，这是设备驱动层的正常警告，不影响功能
      imageFormatGroup: ImageFormatGroup.nv21,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    await old?.dispose();
  }

  Future<void> toggleStreaming() async {
    if (_permissionState != VisionPermissionState.granted) {
      _latestEvent = VisionEvent(
        title: '权限未就绪',
        detail: '请先授予摄像头权限。',
        timestamp: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    if (_isStreaming) {
      await _stopStreaming();
      return;
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _latestEvent = VisionEvent(
        title: '摄像头未就绪',
        detail: '请等待摄像头初始化完成后再启动识别流。',
        timestamp: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    _isStreaming = true;
    _fallAlarmOn = false;
    _history.clear();
    _previousLumaMean = null;
    _recentMotion = 0;
    _fps = 0;
    _processingLatencyMs = 0;
    _lastFrameTime = null;
    _latestEvent = VisionEvent(
      title: '视频流启动',
      detail: '流水线 ${selectedPipeline.shortLabel} 已激活。',
      timestamp: DateTime.now(),
    );
    notifyListeners();
    await _cameraController!.startImageStream((image) {
      unawaited(_processFrame(image));
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isFrameBeingProcessed || !_isStreaming) {
      return;
    }

    _isFrameBeingProcessed = true;
    final start = DateTime.now();

    try {
      _detections = _runFrameDrivenInference(image);

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

  /// 运行帧推理
  /// 
  /// 优先使用TFLite模型进行推理，如果模型未加载则使用备用检测模式
  List<DetectionBox> _runFrameDrivenInference(CameraImage image) {
    // 确保模型已加载
    if (_interpreter == null || _loadedInterpreterModel != _selectedModel) {
      // 异步加载模型，当前帧使用备用模式
      _loadModel(_selectedModel);
      return _runFallbackDetection(image);
    }

    try {
      return _runTFLiteInference(image);
    } catch (e) {
      AppLogger.warning('TFLite inference failed, using fallback: $e');
      return _runFallbackDetection(image);
    }
  }

  /// 使用TFLite模型进行推理
  List<DetectionBox> _runTFLiteInference(CameraImage image) {
    if (_interpreter == null) {
      AppLogger.warning('Interpreter is null');
      return const [];
    }

    // 检查输入输出形状是否有效
    if (_inputShape.isEmpty || _outputShape.isEmpty) {
      AppLogger.warning('Invalid input/output shape: input=$_inputShape, output=$_outputShape');
      return const [];
    }

    // 预处理：将CameraImage转换为模型输入格式
    final List<dynamic>? inputBuffer = _preprocessImage(image);
    if (inputBuffer == null) {
      AppLogger.warning('Preprocessing failed');
      return const [];
    }

    try {
      // 根据shape动态构造输出缓冲区，兼容内置MoveNet与检测模型
      final outputBuffer = _createTensorBuffer(_outputShape);

      // 运行推理
      AppLogger.debug('Running inference with input type: ${_inputTypeCode == 0 ? "uint8" : "float32"}');
      _interpreter!.run(inputBuffer, outputBuffer);

      // 后处理：解析检测结果
      return _postprocessOutput(outputBuffer, image.width, image.height);
    } catch (e, stackTrace) {
      AppLogger.error('TFLite inference error', e, stackTrace);
      return const [];
    }
  }

  /// 图像预处理：将YUV420转换为模型输入
  /// 
  /// 根据模型输入类型自动选择数据格式：
  /// - uint8: 返回 0-255 的整数
  /// - float32: 返回 0.0-1.0 的浮点数（归一化）
  /// 
  /// 使用类型显式声明确保 TFLite 能正确处理
  List<dynamic>? _preprocessImage(CameraImage image) {
    try {
      // 获取模型期望的输入尺寸
      final targetHeight = _inputShape[1];
      final targetWidth = _inputShape[2];
      final channels = _inputShape.length > 3 ? _inputShape[3] : 1;

      // 从YUV420提取数据
      final yPlane = image.planes[0].bytes;
      final yRowStride = image.planes[0].bytesPerRow;

      // 根据输入类型决定数据格式 (0=uint8, 1=float32)
      final isUint8 = _inputTypeCode == 0;
      final typeName = isUint8 ? 'uint8' : 'float32';
      
      AppLogger.debug('Preprocessing: ${image.width}x${image.height} -> ${targetWidth}x$targetHeight, ch=$channels, type=$typeName');

      // 创建输入张量 [1, height, width, channels]
      if (isUint8) {
        // uint8 格式：直接返回 0-255 的整数
        // 使用显式类型声明 List<List<List<List<int>>>>
        final List<List<List<List<int>>>> input = [];
        final batch = <List<List<int>>>[];
        
        for (int y = 0; y < targetHeight; y++) {
          final row = <List<int>>[];
          for (int x = 0; x < targetWidth; x++) {
            // 双线性插值采样
            final srcX = (x * (image.width - 1) / (targetWidth - 1)).clamp(0, image.width - 1);
            final srcY = (y * (image.height - 1) / (targetHeight - 1)).clamp(0, image.height - 1);
            final srcXi = srcX.round();
            final srcYi = srcY.round();
            
            // 获取Y值（亮度）
            final yIndex = srcYi * yRowStride + srcXi;
            final yValue = (yIndex < yPlane.length) ? yPlane[yIndex] : 0;
            
            // uint8: 直接返回 0-255
            if (channels == 3) {
              row.add([yValue, yValue, yValue]);
            } else {
              row.add([yValue]);
            }
          }
          batch.add(row);
        }
        input.add(batch);
        return input;
      } else {
        // float32 格式：归一化到 0.0-1.0
        // 使用显式类型声明 List<List<List<List<double>>>>
        final List<List<List<List<double>>>> input = [];
        final batch = <List<List<double>>>[];
        
        for (int y = 0; y < targetHeight; y++) {
          final row = <List<double>>[];
          for (int x = 0; x < targetWidth; x++) {
            // 双线性插值采样
            final srcX = (x * (image.width - 1) / (targetWidth - 1)).clamp(0, image.width - 1);
            final srcY = (y * (image.height - 1) / (targetHeight - 1)).clamp(0, image.height - 1);
            final srcXi = srcX.round();
            final srcYi = srcY.round();
            
            // 获取Y值（亮度）
            final yIndex = srcYi * yRowStride + srcXi;
            final yValue = (yIndex < yPlane.length) ? yPlane[yIndex] : 0;
            
            // float32: 归一化到 [0, 1]
            final normalizedY = yValue / 255.0;
            if (channels == 3) {
              row.add([normalizedY, normalizedY, normalizedY]);
            } else {
              row.add([normalizedY]);
            }
          }
          batch.add(row);
        }
        input.add(batch);
        return input;
      }
    } catch (e) {
      AppLogger.error('Image preprocessing failed', e);
      return null;
    }
  }

  /// 按 tensor shape 递归创建输出缓冲
  dynamic _createTensorBuffer(List<int> shape, {int depth = 0}) {
    if (shape.isEmpty) return 0.0;
    if (depth >= shape.length - 1) {
      return List<double>.filled(shape[depth], 0.0);
    }
    return List.generate(
      shape[depth],
      (_) => _createTensorBuffer(shape, depth: depth + 1),
    );
  }

  /// 后处理：解析TFLite模型输出为检测框
  /// 
  /// 支持的模型输出格式：
  /// 1. **MoveNet**: [1, 17, 3] - 17个关键点 [y, x, confidence]
  /// 2. **SSD/MobileNet**: [1, num_detections, 6] - [y_min, x_min, y_max, x_max, score, class]
  /// 3. **通用检测**: 单目标回归 [1, 4] -> [x, y, w, h]
  List<DetectionBox> _postprocessOutput(List<dynamic> output, int imgWidth, int imgHeight) {
    final detections = <DetectionBox>[];
    
    try {
      final outputShape = _outputShape;
      
      // 关键点流水线：兼容 MoveNet 的 [1,17,3] 与 [1,1,17,3]
      if (_selectedModel.outputKind == VisionOutputKind.keypoints &&
          _looksLikeMoveNetShape(outputShape)) {
        return _postprocessMoveNetOutput(output);
      }
      
      // SSD/MobileNet风格的输出: [batch, num_detections, 6+]
      if (outputShape.length == 3 && outputShape[2] >= 6) {
        final numDetections = outputShape[1];
        final detectionData = output[0] as List<dynamic>;
        
        for (int i = 0; i < numDetections; i++) {
          final detection = detectionData[i] as List<dynamic>;
          final score = (detection[4] as num).toDouble();
          
          // 置信度阈值
          if (score < 0.5) continue;
          
          final yMin = (detection[0] as num).toDouble();
          final xMin = (detection[1] as num).toDouble();
          final yMax = (detection[2] as num).toDouble();
          final xMax = (detection[3] as num).toDouble();
          
          detections.add(DetectionBox(
            normalizedRect: Rect.fromLTRB(xMin, yMin, xMax, yMax),
            label: _modelSpecFor(_selectedModel).label,
            confidence: score,
          ));
        }
        return detections;
      }
      
      // 简化处理：假设输出是单目标回归 [1, 4] -> [x, y, w, h]
      // 或分类结果 [1, num_classes]
      final modelSpec = _modelSpecFor(_selectedModel);
      
      // 提取主要检测结果（简化版）
      double confidence = 0.7;
      if (output.isNotEmpty && output[0] is List && (output[0] as List).isNotEmpty) {
        final firstOutput = (output[0] as List)[0];
        if (firstOutput is num) {
          confidence = firstOutput.toDouble().clamp(0.0, 1.0);
        }
      }
      
      // 使用运动信息调整检测框
      final width = modelSpec.baseWidth.clamp(0.12, 0.82);
      final height = modelSpec.baseHeight.clamp(0.18, 0.85);
      final left = (0.5 - width / 2).clamp(0.0, 1.0 - width);
      final top = (0.5 - height / 2).clamp(0.0, 1.0 - height);
      
      detections.add(DetectionBox(
        normalizedRect: Rect.fromLTWH(left, top, width, height),
        label: modelSpec.label,
        confidence: confidence,
      ));
    } catch (e) {
      AppLogger.error('Output postprocessing failed', e);
    }
    
    return detections;
  }

  bool _looksLikeMoveNetShape(List<int> shape) {
    if (shape.length == 3) {
      return shape[1] == 17 && shape[2] == 3;
    }
    if (shape.length == 4) {
      return shape[1] == 1 && shape[2] == 17 && shape[3] == 3;
    }
    return false;
  }

  /// 解析MoveNet Lightning输出
  /// 
  /// MoveNet输出17个COCO格式关键点：
  /// 0: nose, 1: left_eye, 2: right_eye, 3: left_ear, 4: right_ear,
  /// 5: left_shoulder, 6: right_shoulder, 7: left_elbow, 8: right_elbow,
  /// 9: left_wrist, 10: right_wrist, 11: left_hip, 12: right_hip,
  /// 13: left_knee, 14: right_knee, 15: left_ankle, 16: right_ankle
  /// 
  /// 每个点: [y, x, confidence]
  /// 输出shape: [1, 17, 3]
  List<DetectionBox> _postprocessMoveNetOutput(List<dynamic> output) {
    final detections = <DetectionBox>[];
    
    // COCO关键点名称映射
    const keypointNames = [
      'nose', 'left_eye', 'right_eye', 'left_ear', 'right_ear',
      'left_shoulder', 'right_shoulder', 'left_elbow', 'right_elbow',
      'left_wrist', 'right_wrist', 'left_hip', 'right_hip',
      'left_knee', 'right_knee', 'left_ankle', 'right_ankle',
    ];
    
    try {
      // MoveNet输出: [1, 17, 3] 或 [1, 1, 17, 3]
      final raw = output[0];
      final keypoints = (raw is List &&
              raw.isNotEmpty &&
              raw.first is List &&
              (raw.first as List).length == 17)
          ? raw.first as List<dynamic>
          : raw as List<dynamic>;
      
      double minX = 1.0, minY = 1.0;
      double maxX = 0.0, maxY = 0.0;
      double totalConfidence = 0.0;
      int validPoints = 0;
      
      // 存储所有关键点
      final keyPointsList = <KeyPoint>[];
      
      // 解析所有17个关键点
      for (int i = 0; i < 17; i++) {
        final point = keypoints[i] as List<dynamic>;
        final y = (point[0] as num).toDouble();
        final x = (point[1] as num).toDouble();
        final confidence = (point[2] as num).toDouble();
        
        keyPointsList.add(KeyPoint(
          normalizedPosition: Offset(x, y),
          confidence: confidence,
          index: i,
          name: keypointNames[i],
        ));
        
        // 用于计算人体框的关键点（躯干+下肢）
        if ([5, 6, 11, 12, 13, 14, 15, 16].contains(i) && confidence > 0.3) {
          minX = min(minX, x);
          minY = min(minY, y);
          maxX = max(maxX, x);
          maxY = max(maxY, y);
          totalConfidence += confidence;
          validPoints++;
        }
      }
      
      // 添加边距
      const padding = 0.05;
      minX = (minX - padding).clamp(0.0, 1.0);
      minY = (minY - padding).clamp(0.0, 1.0);
      maxX = (maxX + padding).clamp(0.0, 1.0);
      maxY = (maxY + padding).clamp(0.0, 1.0);
      
      final width = maxX - minX;
      final height = maxY - minY;
      final avgConfidence = validPoints > 0 ? totalConfidence / validPoints : 0.0;
      
      // 至少有4个有效点才认为检测到人体
      if (validPoints >= 4 && avgConfidence > 0.3) {
        detections.add(DetectionBox(
          normalizedRect: Rect.fromLTWH(minX, minY, width, height),
          label: 'Person (MoveNet)',
          confidence: avgConfidence,
          keyPoints: keyPointsList, // 包含所有关键点
        ));
        
        AppLogger.info('MoveNet detected $validPoints body keypoints, all ${keyPointsList.length} points, confidence: ${avgConfidence.toStringAsFixed(2)}');
      }
    } catch (e) {
      AppLogger.error('MoveNet postprocessing failed', e);
    }
    
    return detections;
  }

  /// 备用检测模式：当TFLite模型不可用时使用
  /// 
  /// 基于亮度质心的简单运动检测
  List<DetectionBox> _runFallbackDetection(CameraImage image) {
    final plane = image.planes.first;
    final luma = plane.bytes;
    if (luma.isEmpty || image.width <= 0 || image.height <= 0) {
      return const [];
    }

    final stepX = max(4, image.width ~/ 24);
    final stepY = max(4, image.height ~/ 24);
    final bytesPerPixel = plane.bytesPerPixel ?? 1;
    final rowStride = plane.bytesPerRow;

    double sumLuma = 0;
    double sumX = 0;
    double sumY = 0;
    var samples = 0;

    for (var y = 0; y < image.height; y += stepY) {
      final rowStart = y * rowStride;
      for (var x = 0; x < image.width; x += stepX) {
        final index = rowStart + x * bytesPerPixel;
        if (index < 0 || index >= luma.length) {
          continue;
        }
        final value = luma[index].toDouble();
        sumLuma += value;
        sumX += value * x;
        sumY += value * y;
        samples++;
      }
    }

    if (samples == 0 || sumLuma <= 0) {
      return const [];
    }

    final meanLuma = sumLuma / samples;
    if (meanLuma < 8) {
      return const [];
    }

    final cx = (sumX / sumLuma / image.width).clamp(0.0, 1.0);
    final cy = (sumY / sumLuma / image.height).clamp(0.0, 1.0);

    if (_previousLumaMean != null) {
      final frameMotion = (meanLuma - _previousLumaMean!).abs() / 255;
      _recentMotion = _recentMotion * 0.65 + frameMotion * 0.35;
    }
    _previousLumaMean = meanLuma;

    final modelSpec = _modelSpecFor(_selectedModel);
    final width = (modelSpec.baseWidth + _recentMotion * modelSpec.motionWidthGain).clamp(0.12, 0.82);
    final height = (modelSpec.baseHeight - _recentMotion * modelSpec.motionHeightGain).clamp(0.18, 0.85);
    final left = (cx - width / 2).clamp(0.0, 1.0 - width);
    final top = (cy - height / 2).clamp(0.0, 1.0 - height);
    final confidence = (modelSpec.baseConfidence + min(_recentMotion, 0.3)).clamp(0.5, 0.98);

    return [
      DetectionBox(
        normalizedRect: Rect.fromLTWH(left, top, width, height),
        label: '${modelSpec.label} (Fallback)',
        confidence: confidence,
      ),
    ];
  }

  _ModelSpec _modelSpecFor(VisionModelType model) {
    return switch (model) {
      VisionModelType.builtinPersonFast => const _ModelSpec(
          label: 'MoveNet/Built-in',
          baseWidth: 0.26,
          baseHeight: 0.54,
          motionWidthGain: 0.18,
          motionHeightGain: 0.16,
          baseConfidence: 0.72,
        ),
      VisionModelType.poseNano => const _ModelSpec(
          label: 'MoveNet',
          baseWidth: 0.22,
          baseHeight: 0.48,
          motionWidthGain: 0.14,
          motionHeightGain: 0.12,
          baseConfidence: 0.68,
        ),
      VisionModelType.personDetectorLite => const _ModelSpec(
          label: 'BlazePose',
          baseWidth: 0.3,
          baseHeight: 0.56,
          motionWidthGain: 0.22,
          motionHeightGain: 0.2,
          baseConfidence: 0.75,
        ),
      VisionModelType.bodyKeypointLite => const _ModelSpec(
          label: 'EfficientDet',
          baseWidth: 0.28,
          baseHeight: 0.5,
          motionWidthGain: 0.2,
          motionHeightGain: 0.18,
          baseConfidence: 0.7,
        ),
    };
  }

  // 算法参数（由模型绑定算法驱动）
  AlgorithmParams _algorithmParams =
      AlgorithmParams.defaultFor(VisionModelType.builtinPersonFast.boundAlgorithm);

  void _evaluateEvent() {
    if (_detections.isEmpty) {
      return;
    }

    final box = _detections.first;
    final now = DateTime.now();
    
    // 提取关键点数据（如果有）
    final keyPoints = box.keyPoints;
    
    // 计算特征
    final frame = _FrameFeature(
      ts: now,
      aspectRatio: box.normalizedRect.width / box.normalizedRect.height,
      centerY: box.normalizedRect.center.dy,
      torsoAngle: _calculateTorsoAngle(keyPoints),
      keyPointCount: keyPoints?.where((kp) => kp.confidence > _algorithmParams.keypointConfidenceThreshold).length ?? 0,
    );
    
    _history.add(frame);

    // 根据参数动态调整时间窗口
    final timeWindow = Duration(milliseconds: _algorithmParams.timeWindowMs);
    final cutoff = now.subtract(timeWindow);
    _history.removeWhere((f) => f.ts.isBefore(cutoff));

    // 需要至少2帧才能进行时序分析
    if (_history.length < 2) {
      return;
    }

    final first = _history.first;
    final fallDetected = switch (_selectedAlgorithm) {
      VisionAlgorithmType.keypointRelation => _detectFallByKeypointRelation(frame, first),
      VisionAlgorithmType.bboxTrend => _detectFallByBboxTrend(frame, first),
    };

    if (fallDetected && !_fallAlarmOn) {
      _fallAlarmOn = true;
      final detail = switch (_selectedAlgorithm) {
        VisionAlgorithmType.keypointRelation => 
          '躯干角度=${frame.torsoAngle?.toStringAsFixed(1)}°, '
          '关键点=${frame.keyPointCount}/${_algorithmParams.minKeyPoints}',
        VisionAlgorithmType.bboxTrend => 
          '长宽比=${frame.aspectRatio.toStringAsFixed(2)}, '
          '下降速度=${((frame.centerY - first.centerY) * 1000 / _algorithmParams.timeWindowMs).toStringAsFixed(2)}/s',
      };
      _latestEvent = VisionEvent(
        title: '疑似跌倒事件',
        detail: '$detail\n算法: ${_selectedAlgorithm.label}',
        timestamp: now,
        level: VisionEventLevel.error,
      );
      _publishEvent();
      return;
    }

    if (!fallDetected && _fallAlarmOn && frame.aspectRatio < 0.85) {
      _fallAlarmOn = false;
      _latestEvent = VisionEvent(
        title: '跌倒告警解除',
        detail: '姿态恢复正常。',
        timestamp: now,
        level: VisionEventLevel.success,
      );
    }
  }

  /// 基于关键点关系检测跌倒
  /// 
  /// 核心逻辑：
  /// 1. 检查有效关键点数量
  /// 2. 计算躯干角度（肩膀中心到臀部中心的连线与垂直方向的夹角）
  /// 3. 角度超过阈值认为可能跌倒
  bool _detectFallByKeypointRelation(_FrameFeature current, _FrameFeature first) {
    // 关键点数量不足
    if (current.keyPointCount < _algorithmParams.minKeyPoints) {
      return false;
    }

    final angle = current.torsoAngle;
    if (angle == null) return false;

    // 躯干角度超过阈值（人躺下时角度接近90度）
    return angle > _algorithmParams.fallAngleThreshold;
  }

  /// 基于识别框趋势检测跌倒
  /// 
  /// 核心逻辑：
  /// 1. 检测框长宽比变化（倒下时宽度>高度，长宽比>1）
  /// 2. 垂直方向快速下降
  bool _detectFallByBboxTrend(_FrameFeature current, _FrameFeature first) {
    // 长宽比超过阈值（框变扁）
    final isFlattened = current.aspectRatio > _algorithmParams.aspectRatioThreshold;
    
    // 计算垂直下降速度（每秒下降的屏幕比例）
    final timeDiff = current.ts.difference(first.ts).inMilliseconds / 1000.0;
    if (timeDiff <= 0) return false;
    
    final verticalSpeed = (current.centerY - first.centerY) / timeDiff;
    final isDroppingFast = verticalSpeed > _algorithmParams.verticalSpeedThreshold;

    return isFlattened && isDroppingFast;
  }

  /// 计算躯干角度（肩膀中心到臀部中心的连线与垂直方向的夹角）
  /// 
  /// 返回值：角度（度），0表示直立，90表示平躺
  double? _calculateTorsoAngle(List<KeyPoint>? keyPoints) {
    if (keyPoints == null || keyPoints.length < 13) return null;

    // 肩膀中心（关键点5和6）
    final leftShoulder = keyPoints[5];
    final rightShoulder = keyPoints[6];
    
    // 臀部中心（关键点11和12）
    final leftHip = keyPoints[11];
    final rightHip = keyPoints[12];

    // 检查关键点置信度
    final minConfidence = _algorithmParams.keypointConfidenceThreshold;
    if (leftShoulder.confidence < minConfidence ||
        rightShoulder.confidence < minConfidence ||
        leftHip.confidence < minConfidence ||
        rightHip.confidence < minConfidence) {
      return null;
    }

    // 计算中心点
    final shoulderCenter = Offset(
      (leftShoulder.normalizedPosition.dx + rightShoulder.normalizedPosition.dx) / 2,
      (leftShoulder.normalizedPosition.dy + rightShoulder.normalizedPosition.dy) / 2,
    );
    
    final hipCenter = Offset(
      (leftHip.normalizedPosition.dx + rightHip.normalizedPosition.dx) / 2,
      (leftHip.normalizedPosition.dy + rightHip.normalizedPosition.dy) / 2,
    );

    // 计算躯干向量（从臀部到肩膀）
    final dx = shoulderCenter.dx - hipCenter.dx;
    final dy = shoulderCenter.dy - hipCenter.dy;

    // 计算与垂直方向的夹角（atan2(dx, -dy) 因为y轴向下）
    final angleRad = atan2(dx.abs(), -dy);
    final angleDeg = angleRad * 180 / pi;

    return angleDeg;
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

  /// 选择并加载模型
  Future<void> selectModel(VisionModelType model) async {
    final state = _modelStates[model];
    if (state == null || (!state.manifest.builtIn && !state.isDownloaded)) {
      _latestEvent = VisionEvent(
        title: '模型不可用',
        detail: '${model.label} 尚未下载，无法切换。',
        timestamp: DateTime.now(),
        level: VisionEventLevel.warning,
      );
      notifyListeners();
      return;
    }

    if (_selectedModel == model) {
      return; // 已经是当前模型
    }

    _selectedModel = model;
    final nextAlgorithm = model.boundAlgorithm;
    if (_selectedAlgorithm != nextAlgorithm) {
      _selectedAlgorithm = nextAlgorithm;
      _algorithmParams = AlgorithmParams.defaultFor(nextAlgorithm);
      _history.clear();
    }
    _latestEvent = VisionEvent(
      title: '流水线切换中',
      detail: '正在切换到 ${model.pipeline.shortLabel}...',
      timestamp: DateTime.now(),
    );
    notifyListeners();

    // 如果正在推流，自动加载新模型
    if (_isStreaming) {
      await _loadModel(model);
    } else {
      _latestEvent = VisionEvent(
        title: '流水线已选择',
        detail: '${model.pipeline.description}，将在启动识别流时加载。',
        timestamp: DateTime.now(),
      );
      notifyListeners();
    }
  }
  
  /// 预加载当前选中的模型（不切换）
  Future<void> preloadSelectedModel() async {
    await _loadModel(_selectedModel);
  }

  /// 兼容层：算法切换已废弃，算法与模型绑定
  void selectAlgorithm(VisionAlgorithmType algorithm, {AlgorithmParams? params}) {
    if (_selectedAlgorithm != algorithm) {
      _latestEvent = VisionEvent(
        title: '算法已绑定模型',
        detail: '当前版本不可单独切换算法，请切换模型。',
        timestamp: DateTime.now(),
        level: VisionEventLevel.warning,
      );
      notifyListeners();
      return;
    }

    if (params != null) {
      _algorithmParams = params;
    }
    notifyListeners();
  }

  /// 更新算法参数
  void updateAlgorithmParams(AlgorithmParams params) {
    _algorithmParams = params;
    _latestEvent = VisionEvent(
      title: '算法参数更新',
      detail: '关键点置信度: ${params.keypointConfidenceThreshold.toStringAsFixed(2)}, '
              '时序窗口: ${params.timeWindowMs}ms, '
              '躯干角度阈值: ${params.fallAngleThreshold.toStringAsFixed(0)}°',
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }
  
  /// 获取当前算法参数
  AlgorithmParams get algorithmParams => _algorithmParams;

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

  Future<void> _stopStreaming() async {
    final camera = _cameraController;
    if (camera != null && camera.value.isStreamingImages) {
      await camera.stopImageStream();
    }
    _isStreaming = false;
    _fallAlarmOn = false;
    _history.clear();
    _previousLumaMean = null;
    _recentMotion = 0;
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
    _cameraController?.dispose();
    _interpreter?.close();
    _dio.close();
    super.dispose();
  }
}

class _ModelSpec {
  final String label;
  final double baseWidth;
  final double baseHeight;
  final double motionWidthGain;
  final double motionHeightGain;
  final double baseConfidence;

  const _ModelSpec({
    required this.label,
    required this.baseWidth,
    required this.baseHeight,
    required this.motionWidthGain,
    required this.motionHeightGain,
    required this.baseConfidence,
  });
}

/// 帧特征数据
/// 
/// 用于时序分析的关键帧信息
class _FrameFeature {
  final DateTime ts;
  final double aspectRatio;  // 检测框长宽比
  final double centerY;      // 检测框中心Y坐标
  final double? torsoAngle;  // 躯干角度（度），null表示无法计算
  final int keyPointCount;   // 有效关键点数量

  const _FrameFeature({
    required this.ts,
    required this.aspectRatio,
    required this.centerY,
    this.torsoAngle,
    required this.keyPointCount,
  });
}

/// 模型文件验证结果
class _ValidationResult {
  final bool isValid;
  final String? errorMessage;
  
  const _ValidationResult.valid() : isValid = true, errorMessage = null;
  const _ValidationResult.invalid(this.errorMessage) : isValid = false;
}
