import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../controllers/fall_detector_controller.dart';

class FallDetectorPage extends StatefulWidget {
  const FallDetectorPage({super.key});

  @override
  State<FallDetectorPage> createState() => _FallDetectorPageState();
}

class _FallDetectorPageState extends State<FallDetectorPage> {
  final _serialController = TextEditingController(text: 'DEVICE_001');

  FallDetectorController get _controller => Modular.get<FallDetectorController>();

  @override
  void initState() {
    super.initState();
    _controller.setup();
  }

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('跌倒检测全流程原型')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final state = _controller.state;
          return Column(
            children: [
              Expanded(child: _buildPreview(state)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildModelManager(state),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _serialController,
                        decoration: const InputDecoration(
                          labelText: '设备序列号',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStats(state),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: state.cameraReady && !state.detecting
                                  ? () => _controller.startDetection(serialNumber: _serialController.text)
                                  : null,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('启动检测'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: state.detecting ? _controller.stopDetection : null,
                              icon: const Icon(Icons.stop),
                              label: const Text('停止'),
                            ),
                          ),
                        ],
                      ),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModelManager(FallDetectorState state) {
    final model = state.modelState;
    final config = FallDetectorController.modelConfig;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('模型: ${config.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(config.description),
          if (model.isDownloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: model.downloadProgress),
            Text('下载进度 ${(model.downloadProgress * 100).toStringAsFixed(1)}%'),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: model.isDownloading ? null : _controller.downloadModel,
                child: const Text('在线下载'),
              ),
              FilledButton.tonal(
                onPressed: model.isDownloading ? null : _controller.loadModel,
                child: const Text('加载模型'),
              ),
              OutlinedButton(
                onPressed: model.isDownloading ? null : _controller.deleteModel,
                child: const Text('删除本地模型'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('本地状态: ${model.modelReady ? '可用' : '未就绪'}'),
          if (model.modelPath != null) Text('路径: ${model.modelPath}'),
        ],
      ),
    );
  }

  Widget _buildPreview(FallDetectorState state) {
    final camera = _controller.cameraController;
    if (!state.permissionGranted) {
      return const Center(child: Text('请先授予摄像头权限'));
    }
    if (!state.cameraReady || camera == null || !camera.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(camera),
        IgnorePointer(
          child: CustomPaint(
            painter: _BBoxPainter(state: state),
          ),
        ),
      ],
    );
  }

  Widget _buildStats(FallDetectorState state) {
    final result = state.lastInference;
    final ratio = result?.box.aspectRatio.toStringAsFixed(2) ?? '--';
    final delta = result?.ratioDelta.toStringAsFixed(2) ?? '--';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MQTT: ${state.isConnected ? '已连接' : '未连接'}'),
          Text('检测状态: ${state.detecting ? '运行中' : '已停止'}'),
          Text('宽高比: $ratio  / 变化量: $delta'),
          Text('当前推理: ${result?.modelName ?? '--'} / source=${result?.box.source ?? '--'}'),
          Text('跌倒确认次数: ${state.statistics.fallEventCount}'),
          Text('已发送事件: ${state.statistics.totalSendCount}'),
        ],
      ),
    );
  }
}

class _BBoxPainter extends CustomPainter {
  const _BBoxPainter({required this.state});

  final FallDetectorState state;

  @override
  void paint(Canvas canvas, Size size) {
    final inference = state.lastInference;
    if (inference == null) return;

    final rect = inference.box.toRect(size);
    final isFall = inference.isFallConfirmed;
    final isSuspected = inference.isFallSuspected;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = isFall
          ? Colors.redAccent
          : (isSuspected ? Colors.orangeAccent : Colors.lightGreenAccent);
    canvas.drawRect(rect, paint);

    final tp = TextPainter(
      text: TextSpan(
        text:
            '${inference.box.label} ${(inference.box.confidence * 100).toStringAsFixed(0)}% | ratio ${inference.box.aspectRatio.toStringAsFixed(2)}',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 12);

    final bg = Paint()..color = Colors.black54;
    final labelRect = Rect.fromLTWH(rect.left, (rect.top - 20).clamp(0, size.height - 20), tp.width + 8, 18);
    canvas.drawRect(labelRect, bg);
    tp.paint(canvas, Offset(labelRect.left + 4, labelRect.top + 2));
  }

  @override
  bool shouldRepaint(covariant _BBoxPainter oldDelegate) {
    return oldDelegate.state.lastInference != state.lastInference;
  }
}
