import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../core/di/service_locator.dart';
import '../../core/widgets/cards.dart';
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
    unawaited(_controller.onPageClosed());
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
            onAlgorithmPanelTap: () => _showAlgorithmPanel(context),
            onMqttPanelTap: () => _showMqttPanel(context),
            onEventPanelTap: () => _showEventPanel(context),
          );
        },
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('算法切换', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  // 使用 Flexible + SingleChildScrollView 支持内容滚动
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 当前绑定算法描述
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
                                    _controller.selectedPipeline.description,
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
                          
                          Text('可用算法', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 8),
                          ..._controller.modelStates.map((state) {
                            final model = state.manifest.type;
                            final enabled = state.manifest.builtIn || state.isDownloaded;
                            return Card(
                              child: ListTile(
                                dense: true,
                                title: Text(model.pipeline.shortLabel),
                                subtitle: Text(model.pipeline.description),
                                trailing: _controller.selectedModel == model
                                    ? const Icon(Icons.check_circle, color: Colors.green)
                                    : null,
                                enabled: enabled,
                                onTap: enabled
                                    ? () => _controller.switchAlgorithmByModel(model)
                                    : null,
                              ),
                            );
                          }),

                          const SizedBox(height: 16),
                          Text('识别模式', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 8),
                          SegmentedButton<VisionDetectionMode>(
                            segments: VisionDetectionMode.values
                                .map(
                                  (mode) => ButtonSegment<VisionDetectionMode>(
                                    value: mode,
                                    label: Text(mode.label),
                                  ),
                                )
                                .toList(),
                            selected: {_controller.detectionMode},
                            onSelectionChanged: (values) {
                              _controller.setDetectionMode(values.first);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 控制按钮固定在底部
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
      ),
    );
  }

  Future<void> _showMqttPanel(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
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
      ),
    );
  }

  Future<void> _showEventPanel(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('状态与事件', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                // 使用 Flexible + SingleChildScrollView 支持内容滚动
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ModernCard(
                          borderRadius: BorderRadius.circular(16),
                          child: _EventBar(event: _controller.latestEvent),
                        ),
                        // 预留空间用于显示更多事件历史
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraWorkbench extends StatelessWidget {
  const _CameraWorkbench({
    required this.controller,
    required this.onAlgorithmPanelTap,
    required this.onMqttPanelTap,
    required this.onEventPanelTap,
  });

  final VisionDetectionController controller;
  final VoidCallback onAlgorithmPanelTap;
  final VoidCallback onMqttPanelTap;
  final VoidCallback onEventPanelTap;

  @override
  Widget build(BuildContext context) {
    if (controller.permissionState != VisionPermissionState.granted) {
      return _PermissionBlock(controller: controller);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 官方 YOLO SDK 组件：内置相机预览 + 推理 + 叠加层
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !controller.isStreaming,
            child: controller.isStreaming
                ? YOLOView(
                    modelPath: controller.yoloModelPath,
                    task: _taskFor(controller.selectedModel),
                    onResult: (results) {
                      controller.onYoloResult(results.cast<dynamic>());
                    },
                  )
                : const ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: Text(
                        '点击右上角开始 YOLO 识别流',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
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
        // 注意：旋转由系统控制，UI始终以初始形态展示
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部栏：返回按钮 + 标题 + 播放/暂停
                _buildTopBar(context),
                
                const SizedBox(height: 12),
                
                // 性能指标栏：FPS + 延迟 + 模型信息（同一行紧凑布局）
                _buildMetricsRow(),
                
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
  /// 
  /// 紧凑布局：FPS | 延迟 | 模型信息（右侧）
  /// 所有 badge 使用统一的 compact 样式确保高度一致
  Widget _buildMetricsRow() {
    return Row(
      children: [
        _MetricBadge(
          text: '推理FPS ${controller.inferenceFps}',
          color: Colors.blueAccent,
          icon: Icons.speed,
          compact: true,
        ),
        const SizedBox(width: 8),
        _MetricBadge(
          text: '${controller.processingLatencyMs}ms',
          color: Colors.green,
          icon: Icons.timer,
          compact: true,
        ),
        const Spacer(),
        // 模型信息放在同一行右侧
        _MetricBadge(
          text: controller.selectedPipeline.shortLabel,
          color: Colors.orangeAccent,
          icon: Icons.memory,
          compact: true,
        ),
      ],
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

YOLOTask _taskFor(VisionModelType model) {
  return switch (model) {
    VisionModelType.builtinPersonFast => YOLOTask.detect,
    VisionModelType.poseNano => YOLOTask.pose,
    VisionModelType.personDetectorLite => YOLOTask.segment,
    VisionModelType.bodyKeypointLite => YOLOTask.obb,
  };
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
    this.compact = false,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10, 
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 10 : 12, color: color),
            SizedBox(width: compact ? 3 : 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.w600,
              fontSize: compact ? 10 : 12,
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
