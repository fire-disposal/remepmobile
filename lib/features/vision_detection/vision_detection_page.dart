import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/widgets/cards.dart';
import 'detection_overlay_painter.dart';
import 'vision_detection_controller.dart';
import 'vision_detection_models.dart';

class VisionDetectionPage extends StatefulWidget {
  const VisionDetectionPage({super.key});

  @override
  State<VisionDetectionPage> createState() => _VisionDetectionPageState();
}

class _VisionDetectionPageState extends State<VisionDetectionPage> {
  late final VisionDetectionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = getIt<VisionDetectionController>();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视觉识别实验台')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: 6,
                  child: _CameraPanel(controller: _controller),
                ),
                Expanded(
                  flex: 5,
                  child: _ControlPanel(controller: _controller),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CameraPanel extends StatelessWidget {
  const _CameraPanel({required this.controller});

  final VisionDetectionController controller;

  @override
  Widget build(BuildContext context) {
    final camera = controller.cameraController;
    final canPreview = camera?.value.isInitialized ?? false;

    if (!canPreview) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(camera!),
            RepaintBoundary(
              child: CustomPaint(
                painter: DetectionOverlayPainter(controller.detections),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: _MetricBadge(
                text: 'FPS ${controller.fps}',
                color: Colors.blueAccent,
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: _MetricBadge(
                text: '延迟 ${controller.processingLatencyMs} ms',
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.controller});

  final VisionDetectionController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        ModernCard(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('模型切换'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: VisionModelType.values
                    .map(
                      (model) => ChoiceChip(
                        label: Text(model.label),
                        selected: model == controller.selectedModel,
                        onSelected: (_) => controller.selectModel(model),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              _SectionTitle('算法切换'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: VisionAlgorithmType.values
                    .map(
                      (algo) => ChoiceChip(
                        label: Text(algo.label),
                        selected: algo == controller.selectedAlgorithm,
                        onSelected: (_) => controller.selectAlgorithm(algo),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              _SectionTitle('MQTT 地址配置'),
              const SizedBox(height: 10),
              _MqttConfigRow(controller: controller),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: controller.toggleStreaming,
                icon: Icon(controller.isStreaming ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(controller.isStreaming ? '暂停识别流' : '启动识别流'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ModernCard(
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              const Icon(Icons.explore_rounded, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '重力方向: ${controller.gravitySnapshot.dominantAxis} | '
                  'g=(${controller.gravitySnapshot.x.toStringAsFixed(1)}, '
                  '${controller.gravitySnapshot.y.toStringAsFixed(1)}, '
                  '${controller.gravitySnapshot.z.toStringAsFixed(1)})',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ModernCard(
          borderRadius: BorderRadius.circular(20),
          child: _EventBar(event: controller.latestEvent),
        ),
      ],
    );
  }
}

class _MqttConfigRow extends StatefulWidget {
  const _MqttConfigRow({required this.controller});

  final VisionDetectionController controller;

  @override
  State<_MqttConfigRow> createState() => _MqttConfigRowState();
}

class _MqttConfigRowState extends State<_MqttConfigRow> {
  late final TextEditingController _brokerCtrl;
  late final TextEditingController _portCtrl;

  @override
  void initState() {
    super.initState();
    _brokerCtrl = TextEditingController(text: widget.controller.mqttBroker);
    _portCtrl = TextEditingController(text: widget.controller.mqttPort.toString());
  }

  @override
  void dispose() {
    _brokerCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _brokerCtrl,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Broker',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 96,
          child: TextField(
            controller: _portCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Port',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: '连接 MQTT',
          onPressed: () async {
            final port = int.tryParse(_portCtrl.text.trim()) ?? widget.controller.mqttPort;
            await widget.controller.updateMqttConfig(
              broker: _brokerCtrl.text.trim(),
              port: port,
            );
          },
          icon: const Icon(Icons.wifi_tethering),
        ),
      ],
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _EventBar extends StatelessWidget {
  const _EventBar({required this.event});

  final VisionEvent? event;

  @override
  Widget build(BuildContext context) {
    if (event == null) {
      return const Text('事件条：等待算法输出事件...');
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.notifications_active_rounded, color: Colors.redAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${event!.timeLabel} · ${event!.title}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(event!.detail),
            ],
          ),
        ),
      ],
    );
  }
}
