import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelDownloadConfig {
  const ModelDownloadConfig({
    required this.name,
    required this.url,
    required this.inputSize,
    required this.description,
  });

  final String name;
  final String url;
  final int inputSize;
  final String description;

  static const moveNetLightning = ModelDownloadConfig(
    name: 'movenet_lightning_fp16',
    url: 'https://storage.googleapis.com/tfhub-lite-models/google/lite-model/movenet/singlepose/lightning/tflite/float16/4.tflite',
    inputSize: 192,
    description: 'MoveNet Lightning（单人姿态，轻量级，适合移动端实时）',
  );
}

class ModelManagerState {
  const ModelManagerState({
    this.isDownloading = false,
    this.downloadProgress = 0,
    this.modelReady = false,
    this.modelPath,
    this.error,
  });

  final bool isDownloading;
  final double downloadProgress;
  final bool modelReady;
  final String? modelPath;
  final String? error;

  ModelManagerState copyWith({
    bool? isDownloading,
    double? downloadProgress,
    bool? modelReady,
    String? modelPath,
    String? error,
  }) {
    return ModelManagerState(
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      modelReady: modelReady ?? this.modelReady,
      modelPath: modelPath ?? this.modelPath,
      error: error,
    );
  }
}

class ModelManagerService {
  final Dio _dio = Dio();
  Interpreter? _interpreter;

  ModelManagerState _state = const ModelManagerState();
  ModelManagerState get state => _state;

  Interpreter? get interpreter => _interpreter;

  Future<String> _resolvePath(ModelDownloadConfig config) async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/models');
    if (!modelDir.existsSync()) {
      modelDir.createSync(recursive: true);
    }
    return '${modelDir.path}/${config.name}.tflite';
  }

  Future<ModelManagerState> refresh(ModelDownloadConfig config) async {
    final path = await _resolvePath(config);
    final exists = File(path).existsSync();
    _state = _state.copyWith(modelPath: path, modelReady: exists, error: null);
    return _state;
  }

  Future<ModelManagerState> downloadModel(
    ModelDownloadConfig config, {
    void Function(ModelManagerState state)? onProgress,
  }) async {
    final path = await _resolvePath(config);
    _state = _state.copyWith(isDownloading: true, downloadProgress: 0, modelPath: path, error: null);

    try {
      await _dio.download(
        config.url,
        path,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          _state = _state.copyWith(downloadProgress: received / total, isDownloading: true);
          onProgress?.call(_state);
        },
      );

      _state = _state.copyWith(isDownloading: false, downloadProgress: 1, modelReady: true, error: null);
      onProgress?.call(_state);
      return _state;
    } catch (e) {
      _state = _state.copyWith(isDownloading: false, error: '模型下载失败: $e');
      onProgress?.call(_state);
      return _state;
    }
  }

  Future<ModelManagerState> loadModel(ModelDownloadConfig config) async {
    final path = await _resolvePath(config);
    if (!File(path).existsSync()) {
      _state = _state.copyWith(modelReady: false, error: '模型文件不存在，请先下载');
      return _state;
    }

    try {
      _interpreter?.close();
      _interpreter = Interpreter.fromFile(File(path));
      _state = _state.copyWith(modelPath: path, modelReady: true, error: null);
      return _state;
    } catch (e) {
      _state = _state.copyWith(modelReady: false, error: '模型加载失败: $e');
      return _state;
    }
  }

  Future<ModelManagerState> deleteModel(ModelDownloadConfig config) async {
    final path = await _resolvePath(config);
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
    _interpreter?.close();
    _interpreter = null;
    _state = _state.copyWith(modelReady: false, downloadProgress: 0, modelPath: path, error: null);
    return _state;
  }

  void dispose() {
    _interpreter?.close();
  }
}
