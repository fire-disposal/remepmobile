import 'package:flutter/material.dart';

import '../../data/services/vision_detection_dev_service.dart';

class VisionFallDetectionPage extends StatefulWidget {
  const VisionFallDetectionPage({super.key});

  @override
  State<VisionFallDetectionPage> createState() => _VisionFallDetectionPageState();
}

class _VisionFallDetectionPageState extends State<VisionFallDetectionPage> {
  final VisionDetectionDevService _service = VisionDetectionDevService();

  VisionDependencyState? _dependencyState;
  VisionInferenceSnapshot? _lastSnapshot;

  bool _checking = false;
  bool _modelLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkDependencies();
  }

  Future<void> _checkDependencies() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final state = await _service.checkDependencies();
      setState(() => _dependencyState = state);
    } catch (e) {
      setState(() => _error = '依赖检查失败：$e');
    } finally {
      setState(() => _checking = false);
    }
  }

  Future<void> _loadModel() async {
    final ok = await _service.loadModel();
    setState(() {
      _modelLoaded = ok;
      _error = ok ? null : '模型加载失败';
    });
  }

  void _runOnce() {
    if (!_modelLoaded) {
      setState(() => _error = '请先加载模型');
      return;
    }

    setState(() {
      _lastSnapshot = _service.simulateInference();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _lastSnapshot;

    return Scaffold(
      appBar: AppBar(title: const Text('视觉跌倒检测')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('视觉识别依赖准备', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _depChip('camera', _dependencyState?.cameraReady ?? false),
                      _depChip('tflite_flutter', _dependencyState?.tfliteReady ?? false),
                      _depChip('permission_handler', _dependencyState?.permissionReady ?? false),
                      _depChip('assets/models', _dependencyState?.modelAssetReady ?? false),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '安装建议：flutter pub add camera tflite_flutter permission_handler path_provider',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _checking ? null : _checkDependencies,
                        child: Text(_checking ? '检查中...' : '重新检查依赖'),
                      ),
                      OutlinedButton(
                        onPressed: _loadModel,
                        child: Text(_modelLoaded ? '模型已加载' : '加载模型'),
                      ),
                      FilledButton.tonal(
                        onPressed: _runOnce,
                        child: const Text('执行一次识别'),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  snapshot == null
                      ? '相机画面占位（下一步接 CameraPreview）'
                      : '结果：${snapshot.label}\n置信度：${(snapshot.confidence * 100).toStringAsFixed(1)}%\n时间：${snapshot.timestamp.toIso8601String()}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _depChip(String label, bool ok) {
    return Chip(
      label: Text('$label ${ok ? '✓' : '✗'}'),
      backgroundColor: ok ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
    );
  }
}
