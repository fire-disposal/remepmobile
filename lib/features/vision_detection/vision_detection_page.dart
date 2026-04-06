import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/widgets/cards.dart';
import 'detection_overlay_painter.dart';
import 'vision_detection_controller.dart';
import 'vision_detection_models.dart';

export 'vision_detection_models.dart' show AlgorithmParams;

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
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('模型管理', style: Theme.of(context).textTheme.titleMedium),
                    if (_controller.isModelLoading)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('加载中...', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_controller.modelLoadError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _controller.modelLoadError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
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
      ),
    );
  }

  Future<void> _showAlgorithmPanel(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('算法配置', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                
                // 算法选择
                Text('检测算法', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                SegmentedButton<VisionAlgorithmType>(
                  showSelectedIcon: false,
                  segments: VisionAlgorithmType.values
                      .map((algo) => ButtonSegment<VisionAlgorithmType>(
                            value: algo, 
                            label: Text(algo.label, style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  selected: <VisionAlgorithmType>{_controller.selectedAlgorithm},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) return;
                    _controller.selectAlgorithm(selection.first);
                  },
                ),
                
                const SizedBox(height: 16),
                
                // 当前算法描述
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, 
                           size: 18, 
                           color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _controller.selectedAlgorithm.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 参数配置
                Text('参数配置', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                _AlgorithmParamsPanel(controller: _controller),
                
                const SizedBox(height: 16),
                
                // 控制按钮
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
        // 相机预览层
        _AdaptiveCameraPreview(camera: camera!),
        
        // 检测框和关键点绘制层
        RepaintBoundary(
          child: CustomPaint(
            painter: DetectionOverlayPainter(controller.detections),
          ),
        ),
        
        // 渐变遮罩层
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x80000000), // 顶部更深的遮罩
                Colors.transparent, 
                Color(0x66000000),
              ],
              stops: [0, 0.35, 1],
            ),
          ),
        ),
        
        // 主UI层 - 使用SafeArea确保不侵入系统区域
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _AutoRotateByGravity(
              turns: controller.uiRotationTurns,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 顶部栏：返回按钮 + 标题 + 播放/暂停
                  _buildTopBar(context),
                  
                  const SizedBox(height: 12),
                  
                  // 性能指标栏：FPS + 延迟
                  _buildMetricsRow(),
                  
                  const SizedBox(height: 8),
                  
                  // 模型信息栏
                  _buildModelInfoBar(),
                  
                  const Spacer(),
                  
                  // 底部区域：跌倒告警 + 快捷操作按钮
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 左下角：跌倒告警
                      if (controller.fallAlarmOn)
                        _buildFallAlarmBadge()
                      else
                        const SizedBox.shrink(),
                      
                      const Spacer(),
                      
                      // 右侧：快捷操作按钮组
                      _buildQuickActionButtons(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建顶部栏
  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton.filledTonal(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 20),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          
          const SizedBox(width: 12),
          
          // 标题
          const Expanded(
            child: Text(
              '视觉识别实验台',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
          
          // 播放/暂停按钮
          IconButton.filled(
            tooltip: controller.isStreaming ? '暂停识别流' : '启动识别流',
            onPressed: controller.toggleStreaming,
            icon: Icon(
              controller.isStreaming ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 20,
            ),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  /// 构建性能指标行
  Widget _buildMetricsRow() {
    return Row(
      children: [
        _MetricBadge(
          text: 'FPS ${controller.fps}',
          color: Colors.blueAccent,
          icon: Icons.speed,
        ),
        const SizedBox(width: 8),
        _MetricBadge(
          text: '${controller.processingLatencyMs}ms',
          color: Colors.green,
          icon: Icons.timer,
        ),
      ],
    );
  }

  /// 构建模型信息栏
  Widget _buildModelInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orangeAccent.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.memory,
            size: 14,
            color: Colors.orangeAccent.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            '${controller.selectedModel.label} · ${controller.selectedAlgorithm.label}',
            style: TextStyle(
              color: Colors.orangeAccent.withValues(alpha: 0.95),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建跌倒告警徽章
  Widget _buildFallAlarmBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_rounded,
            color: Colors.white,
            size: 18,
          ),
          SizedBox(width: 6),
          Text(
            '跌倒告警中',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建快捷操作按钮组
  Widget _buildQuickActionButtons() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        direction: Axis.vertical,
        spacing: 8,
        children: [
          _QuickActionButton(
            icon: Icons.memory_rounded,
            label: '模型',
            onTap: onModelPanelTap,
            isActive: controller.isModelLoading,
          ),
          _QuickActionButton(
            icon: Icons.tune_rounded,
            label: '算法',
            onTap: onAlgorithmPanelTap,
          ),
          _QuickActionButton(
            icon: Icons.wifi_tethering,
            label: 'MQTT',
            onTap: onMqttPanelTap,
          ),
          _QuickActionButton(
            icon: Icons.event_note_rounded,
            label: '事件',
            onTap: onEventPanelTap,
            showBadge: controller.latestEvent != null &&
                       controller.latestEvent!.level == VisionEventLevel.error,
          ),
        ],
      ),
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
    this.isActive = false,
    this.showBadge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FilledButton.tonalIcon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: isActive 
                ? Colors.blue.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.45),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            minimumSize: const Size(0, 40),
          ),
          icon: isActive 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        // 通知徽章
        if (showBadge)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
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
  const _MetricBadge({
    required this.text, 
    required this.color,
    this.icon,
  });

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.w600,
              fontSize: 12,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ],
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
      return const Row(
        children: [
          Icon(Icons.notifications_none_rounded, color: Colors.grey, size: 20),
          SizedBox(width: 10),
          Text('等待算法输出事件...', style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    final levelColor = event!.getLevelColor();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          event!.level == VisionEventLevel.error 
              ? Icons.notifications_active_rounded 
              : event!.level == VisionEventLevel.success
                  ? Icons.check_circle_rounded
                  : Icons.notifications_rounded,
          color: levelColor,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      event!.timeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: levelColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event!.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: levelColor,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                event!.detail,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 算法参数配置面板
class _AlgorithmParamsPanel extends StatefulWidget {
  const _AlgorithmParamsPanel({required this.controller});

  final VisionDetectionController controller;

  @override
  State<_AlgorithmParamsPanel> createState() => _AlgorithmParamsPanelState();
}

class _AlgorithmParamsPanelState extends State<_AlgorithmParamsPanel> {
  late AlgorithmParams _params;

  @override
  void initState() {
    super.initState();
    _params = widget.controller.algorithmParams;
  }

  @override
  void didUpdateWidget(covariant _AlgorithmParamsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _params = widget.controller.algorithmParams;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 置信度阈值
        _ParamSlider(
          label: '置信度阈值',
          value: _params.confidenceThreshold,
          min: 0.1,
          max: 0.95,
          onChanged: (v) => setState(() => _params = _params.copyWith(confidenceThreshold: v)),
          onChangeEnd: (v) => widget.controller.updateAlgorithmParams(
            _params.copyWith(confidenceThreshold: v),
          ),
        ),
        
        // 长宽比阈值
        _ParamSlider(
          label: '跌倒长宽比阈值',
          value: _params.aspectRatioThreshold,
          min: 0.8,
          max: 2.0,
          onChanged: (v) => setState(() => _params = _params.copyWith(aspectRatioThreshold: v)),
          onChangeEnd: (v) => widget.controller.updateAlgorithmParams(
            _params.copyWith(aspectRatioThreshold: v),
          ),
        ),
        
        // 时间窗口
        _ParamSlider(
          label: '时间窗口 (秒)',
          value: _params.timeWindowMs / 1000,
          min: 0.5,
          max: 5.0,
          divisions: 9,
          onChanged: (v) => setState(() => _params = _params.copyWith(timeWindowMs: (v * 1000).round())),
          onChangeEnd: (v) => widget.controller.updateAlgorithmParams(
            _params.copyWith(timeWindowMs: (v * 1000).round()),
          ),
        ),
        
        // 重力方向检查
        if (_params.enableGravityCheck)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.screen_rotation, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('重力方向检测已启用', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}

/// 参数滑块组件
class _ParamSlider extends StatelessWidget {
  const _ParamSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              value.toStringAsFixed(value < 1 ? 2 : 1),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 32,
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}
