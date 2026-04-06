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
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return _CameraWorkbench(
            controller: _controller,
            onModelPanelTap: () => _showModelPanel(context),
            onAlgorithmPanelTap: () => _showAlgorithmPanel(context),
            onMqttPanelTap: () => _showMqttPanel(context),
            onEventPanelTap: () => _showEventPanel(context),
          );
        },
      ),
    );
  }

  Future<void> _showModelPanel(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('模型管理（紧凑）', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ..._controller.modelStates.map(
                (state) => _CompactModelTile(
                  state: state,
                  selected: state.manifest.type == _controller.selectedModel,
                  onSelect: () => _controller.selectModel(state.manifest.type),
                  onDownload: () => _controller.downloadModel(state.manifest.type),
                  onDelete: () => _controller.removeModel(state.manifest.type),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAlgorithmPanel(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('算法切换（紧凑）', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<VisionAlgorithmType>(
                showSelectedIcon: false,
                segments: VisionAlgorithmType.values
                    .map((algo) => ButtonSegment<VisionAlgorithmType>(value: algo, label: Text(algo.label)))
                    .toList(),
                selected: <VisionAlgorithmType>{_controller.selectedAlgorithm},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) {
                    return;
                  }
                  _controller.selectAlgorithm(selection.first);
                },
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                onPressed: _controller.toggleStreaming,
                icon: Icon(_controller.isStreaming ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(_controller.isStreaming ? '暂停识别流' : '启动识别流'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMqttPanel(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MQTT 地址配置', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _MqttConfigRow(controller: _controller),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEventPanel(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('状态与事件', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ModernCard(borderRadius: BorderRadius.circular(16), child: _GravityBar(controller: _controller)),
              const SizedBox(height: 10),
              ModernCard(borderRadius: BorderRadius.circular(16), child: _EventBar(event: _controller.latestEvent)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraWorkbench extends StatelessWidget {
  const _CameraWorkbench({
    required this.controller,
    required this.onModelPanelTap,
    required this.onAlgorithmPanelTap,
    required this.onMqttPanelTap,
    required this.onEventPanelTap,
  });

  final VisionDetectionController controller;
  final VoidCallback onModelPanelTap;
  final VoidCallback onAlgorithmPanelTap;
  final VoidCallback onMqttPanelTap;
  final VoidCallback onEventPanelTap;

  @override
  Widget build(BuildContext context) {
    if (controller.permissionState != VisionPermissionState.granted) {
      return _PermissionBlock(controller: controller);
    }

    final camera = controller.cameraController;
    final canPreview = camera?.value.isInitialized ?? false;

    if (!canPreview) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _AdaptiveCameraPreview(camera: camera!),
        RepaintBoundary(
          child: CustomPaint(
            painter: DetectionOverlayPainter(controller.detections),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Colors.transparent, Color(0x4D000000)],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 56,
          child: _AutoRotateByGravity(
            turns: controller.uiRotationTurns,
            child: _MetricBadge(
              text: 'FPS ${controller.fps}',
              color: Colors.blueAccent,
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 96,
          child: _AutoRotateByGravity(
            turns: controller.uiRotationTurns,
            child: _MetricBadge(
              text: '延迟 ${controller.processingLatencyMs} ms',
              color: Colors.green,
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 56,
          child: _AutoRotateByGravity(
            turns: controller.uiRotationTurns,
            child: _MetricBadge(
              text: '${controller.selectedModel.label} · ${controller.selectedAlgorithm.label}',
              color: Colors.orangeAccent,
            ),
          ),
        ),
        if (controller.fallAlarmOn)
          Positioned(
            left: 16,
            bottom: 48,
            child: _AutoRotateByGravity(
              turns: controller.uiRotationTurns,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '跌倒告警中',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            child: _AutoRotateByGravity(
              turns: controller.uiRotationTurns,
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: '返回',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '视觉识别实验台',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: controller.isStreaming ? '暂停识别流' : '启动识别流',
                        onPressed: controller.toggleStreaming,
                        icon: Icon(
                          controller.isStreaming ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      direction: Axis.vertical,
                      spacing: 10,
                      children: [
                        _QuickActionButton(icon: Icons.memory_rounded, label: '模型', onTap: onModelPanelTap),
                        _QuickActionButton(icon: Icons.tune_rounded, label: '算法', onTap: onAlgorithmPanelTap),
                        _QuickActionButton(icon: Icons.wifi_tethering, label: 'MQTT', onTap: onMqttPanelTap),
                        _QuickActionButton(icon: Icons.event_note_rounded, label: '事件', onTap: onEventPanelTap),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdaptiveCameraPreview extends StatelessWidget {
  const _AdaptiveCameraPreview({required this.camera});

  final CameraController camera;

  @override
  Widget build(BuildContext context) {
    final previewSize = camera.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(camera);
    }

    final screenSize = MediaQuery.sizeOf(context);
    final isPortrait = screenSize.height >= screenSize.width;
    final previewWidth = isPortrait ? previewSize.height : previewSize.width;
    final previewHeight = isPortrait ? previewSize.width : previewSize.height;

    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: CameraPreview(camera),
          ),
        ),
      ),
    );
  }
}

class _AutoRotateByGravity extends StatelessWidget {
  const _AutoRotateByGravity({
    required this.turns,
    required this.child,
  });

  final double turns;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: turns,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: child,
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _PermissionBlock extends StatelessWidget {
  const _PermissionBlock({required this.controller});

  final VisionDetectionController controller;

  @override
  Widget build(BuildContext context) {
    final isPermanent = controller.permissionState == VisionPermissionState.permanentlyDenied;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ModernCard(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.privacy_tip_outlined, size: 42),
            const SizedBox(height: 12),
            Text(
              isPermanent ? '权限被永久拒绝' : '需要摄像头权限',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('可在系统设置页面统一管理权限；检测页内也支持快速授权与跳转设置。'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: controller.requestPermissions,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('请求权限'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.openSystemSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('打开系统设置'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactModelTile extends StatelessWidget {
  const _CompactModelTile({
    required this.state,
    required this.selected,
    required this.onSelect,
    required this.onDownload,
    required this.onDelete,
  });

  final ModelRuntimeState state;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final manifest = state.manifest;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    manifest.type.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  manifest.sizeLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                if (selected)
                  const Icon(Icons.check_circle_rounded, size: 18, color: Colors.green),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                manifest.type.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (state.isDownloading) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: state.progress),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  tooltip: '切换模型',
                  onPressed: (manifest.builtIn || state.isDownloaded) ? onSelect : null,
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
                if (!manifest.builtIn) ...[
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    tooltip: state.isDownloaded ? '重新下载' : '下载模型',
                    onPressed: state.isDownloading ? null : onDownload,
                    icon: Icon(state.isDownloaded ? Icons.download_for_offline_rounded : Icons.download_rounded),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '删除本地',
                    onPressed: state.isDownloaded && !state.isDownloading ? onDelete : null,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ],
            )
          ],
        ),
      ),
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

class _GravityBar extends StatelessWidget {
  const _GravityBar({required this.controller});

  final VisionDetectionController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
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
