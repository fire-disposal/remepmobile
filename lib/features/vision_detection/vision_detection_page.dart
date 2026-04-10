import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../core/di/service_locator.dart';
import '../../core/events/app_event.dart';
import '../../core/theme/design_language.dart';
import '../../core/widgets/cards.dart';
import 'detection_overlay_painter.dart';
import 'vision_detection_controller.dart';
import 'vision_detection_models.dart';

/// 视觉检测页面
/// 
/// 使用固定 YOLO11n Detect 模型进行目标检测
/// 移除了模型切换功能，简化用户使用流程
class VisionDetectionPage extends StatefulWidget {
  const VisionDetectionPage({super.key});

  @override
  State<VisionDetectionPage> createState() => _VisionDetectionPageState();
}

class _VisionDetectionPageState extends State<VisionDetectionPage> {
  late final VisionDetectionController _controller;
  bool _showLiveLog = true;

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
            onSettingsPanelTap: () => _showAlgorithmPanel(context),
            onModelPanelTap: () => _showModelPanel(context),
            onEventPanelTap: () => _showEventPanel(context),
            showLiveLog: _showLiveLog,
            onToggleLiveLog: () => setState(() => _showLiveLog = !_showLiveLog),
          );
        },
      ),
    );
  }

  /// 显示算法参数面板
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
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('跌倒检测算法参数', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AlgorithmSlider(
                            label: '识别框长宽比阈值',
                            value: _controller.algorithmParams.aspectRatioThreshold,
                            min: 0.6,
                            max: 1.6,
                            divisions: 20,
                            formatValue: (v) => v.toStringAsFixed(2),
                            onChanged: (value) {
                              _controller.updateAlgorithmParams(
                                _controller.algorithmParams.copyWith(aspectRatioThreshold: value),
                              );
                            },
                          ),
                          _AlgorithmSlider(
                            label: '垂直速度阈值',
                            value: _controller.algorithmParams.verticalSpeedThreshold,
                            min: 0.1,
                            max: 1.0,
                            divisions: 18,
                            formatValue: (v) => v.toStringAsFixed(2),
                            onChanged: (value) {
                              _controller.updateAlgorithmParams(
                                _controller.algorithmParams.copyWith(verticalSpeedThreshold: value),
                              );
                            },
                          ),
                          _AlgorithmSlider(
                            label: '跌倒角度阈值',
                            value: _controller.algorithmParams.fallAngleThreshold,
                            min: 45,
                            max: 90,
                            divisions: 9,
                            formatValue: (v) => '${v.toStringAsFixed(0)}°',
                            onChanged: (value) {
                              _controller.updateAlgorithmParams(
                                _controller.algorithmParams.copyWith(fallAngleThreshold: value),
                              );
                            },
                          ),
                          _AlgorithmSlider(
                            label: '时间窗口',
                            value: _controller.algorithmParams.timeWindowMs.toDouble(),
                            min: 800,
                            max: 5000,
                            divisions: 21,
                            formatValue: (v) => '${v.toStringAsFixed(0)}ms',
                            onChanged: (value) {
                              _controller.updateAlgorithmParams(
                                _controller.algorithmParams.copyWith(timeWindowMs: value.round()),
                              );
                            },
                          ),
                          _AlgorithmSlider(
                            label: '关键点置信度阈值',
                            value: _controller.algorithmParams.keypointConfidenceThreshold,
                            min: 0.1,
                            max: 0.8,
                            divisions: 14,
                            formatValue: (v) => v.toStringAsFixed(2),
                            onChanged: (value) {
                              _controller.updateAlgorithmParams(
                                _controller.algorithmParams.copyWith(keypointConfidenceThreshold: value),
                              );
                            },
                          ),
                          _AlgorithmSlider(
                            label: '最小关键点数量',
                            value: _controller.algorithmParams.minKeyPoints.toDouble(),
                            min: 3,
                            max: 12,
                            divisions: 9,
                            formatValue: (v) => v.toStringAsFixed(0),
                            onChanged: (value) {
                              _controller.updateAlgorithmParams(
                                _controller.algorithmParams.copyWith(minKeyPoints: value.round()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _controller.resetAlgorithmParams,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('恢复默认'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size(140, 42)),
                        onPressed: _controller.toggleStreaming,
                        icon: Icon(_controller.isStreaming ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(_controller.isStreaming ? '暂停识别流' : '启动识别流'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示模型管理面板
  Future<void> _showModelPanel(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('模型管理', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.memory, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YOLO11n Detect',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _controller.modelStatusMessage,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _controller.isModelReady
                                      ? Theme.of(context).colorScheme.onPrimaryContainer
                                      : Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _controller.modelState.isDownloading
                              ? _controller.modelState.progress
                              : (_controller.modelState.isDownloaded ? 1 : 0),
                          minHeight: 6,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: _controller.modelState.isDownloading
                            ? null
                            : (_controller.canDownloadModel ? _controller.downloadModel : null),
                        child: Text(
                          _controller.modelState.isDownloaded
                              ? '已下载'
                              : (_controller.modelState.isDownloading ? '下载中' : '下载模型'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    value: _controller.preferDownloadedModel,
                    onChanged: (value) => _controller.setPreferDownloadedModel(value),
                    title: const Text('优先使用已下载模型'),
                    subtitle: const Text('关闭后将回退使用内置模型'),
                  ),
                ],
              ),
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
                Flexible(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final events = _controller.visionEvents.take(50).toList(growable: false);
                      if (events.isEmpty) {
                        return Center(
                          child: Text(
                            '暂无事件',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: events.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = events[index];
                          return ModernCard(
                            borderRadius: BorderRadius.circular(16),
                            child: _AppEventTile(event: item),
                          );
                        },
                      );
                    },
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
    required this.onSettingsPanelTap,
    required this.onModelPanelTap,
    required this.onEventPanelTap,
    required this.showLiveLog,
    required this.onToggleLiveLog,
  });

  final VisionDetectionController controller;
  final VoidCallback onSettingsPanelTap;
  final VoidCallback onModelPanelTap;
  final VoidCallback onEventPanelTap;
  final bool showLiveLog;
  final VoidCallback onToggleLiveLog;

  @override
  Widget build(BuildContext context) {
    if (controller.permissionState != VisionPermissionState.granted) {
      return _PermissionBlock(controller: controller);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 官方 YOLO SDK 组件：内置相机预览 + 推理
        Positioned.fill(
          child: YOLOView(
            modelPath: controller.yoloModelPath,
            task: YOLOTask.detect,
            controller: controller.yoloController,
            streamingConfig: controller.streamingConfig,
            showNativeUI: false,
            showOverlays: false,
            onPerformanceMetrics: controller.onYoloPerformanceMetrics,
            onResult: (results) {
              controller.onYoloResult(results);
            },
          ),
        ),
        
        // 当未启动识别流时的遮罩层（保持相机预览可见但提示用户）
        if (!controller.isStreaming)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 48),
                    SizedBox(height: 16),
                    Text(
                      '点击右上角开始 YOLO 识别推理',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // 识别框绘制层 - 仅在流启动且有检测结果时显示
        if (controller.isStreaming)
          Positioned.fill(
            child: CustomPaint(
              painter: DetectionOverlayPainter(
                controller.detections,
                outputKind: controller.selectedPipeline.outputKind,
                drawEmptyIndicator: true, // 新增：如果流启动但没框，绘制十字准星或提示
              ),
              size: Size.infinite,
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
        
        // 主UI层
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppDesignLanguage.pageHorizontalPadding, 12, AppDesignLanguage.pageHorizontalPadding, AppDesignLanguage.pageHorizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部栏
                _buildTopBar(context),
                
                const SizedBox(height: 12),
                
                // 性能指标栏
                _buildMetricsRow(),

                const Spacer(),
                
                // 底部区域
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 左下角：日志面板
                    Flexible(child: _buildBottomLeftPanel(context)),
                    const SizedBox(width: 12),
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
        borderRadius: AppDesignLanguage.panelRadius,
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
          text: '${controller.inferenceFps}',
          color: Colors.blueAccent,
          icon: Icons.speed,
          compact: true,
        ),
        const SizedBox(width: 8),
        _MetricBadge(
          text: '${controller.processingLatencyMs}',
          color: Colors.green,
          icon: Icons.timer,
          compact: true,
        ),
        const SizedBox(width: 8),
        _MetricBadge(
          text: '${controller.detections.length}',
          color: Colors.purpleAccent,
          icon: Icons.person_outline,
          compact: true,
        ),
        const Spacer(),
        // 识别模型标签
        _MetricBadge(
          text: controller.selectedPipeline.modelName,
          color: Colors.orangeAccent,
          icon: Icons.api_rounded,
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
        borderRadius: AppDesignLanguage.panelRadius,
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
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Wrap(
          direction: Axis.vertical,
          spacing: 6,
          children: [
            _QuickActionButton(
              icon: Icons.tune_rounded,
              label: '算法',
              onTap: onSettingsPanelTap,
            ),
            _QuickActionButton(
              icon: Icons.cloud_download_outlined,
              label: '模型',
              onTap: onModelPanelTap,
            ),
            _QuickActionButton(
              icon: showLiveLog ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              label: '日志',
              onTap: onToggleLiveLog,
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
      ),
    );
  }

  Widget _buildBottomLeftPanel(BuildContext context) {
    const double actionButtonHeight = 40;
    const double actionSpacing = 8;
    const double containerPadding = 16;
    const int buttonCount = 4;
    const double logPanelWidth = 260;
    const double panelHeight =
        buttonCount * actionButtonHeight + (buttonCount - 1) * actionSpacing + containerPadding;

    return SizedBox(
      width: logPanelWidth,
      height: panelHeight,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: showLiveLog
            ? SizedBox(
                height: panelHeight,
                width: logPanelWidth,
                child: _buildLiveLogPanel(context),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildLiveLogPanel(BuildContext context) {
    final logs = controller.runtimeLogs.take(6).toList(growable: false);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                '实时日志',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                controller.isStreaming ? '推理中' : '待机',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: controller.isStreaming ? Colors.greenAccent : Colors.white54,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: logs.isEmpty
                ? const Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      '等待推理输出...',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = logs[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.timeLabel,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${item.title} · ${item.detail}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FilledButton.tonalIcon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.45),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 36),
          ),
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12)),
        ),
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


class _AlgorithmSlider extends StatelessWidget {
  const _AlgorithmSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.formatValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value) formatValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                formatValue(value),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: formatValue(value),
            onChanged: onChanged,
          ),
        ],
      ),
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

class _AppEventTile extends StatelessWidget {
  const _AppEventTile({required this.event});

  final AppEvent event;

  Color _levelColor(BuildContext context) {
    return switch (event.level) {
      AppEventLevel.critical => Colors.red,
      AppEventLevel.warning => Colors.orange,
      _ => Theme.of(context).colorScheme.primary,
    };
  }

  IconData _levelIcon() {
    return switch (event.level) {
      AppEventLevel.critical => Icons.notifications_active_rounded,
      AppEventLevel.warning => Icons.warning_rounded,
      _ => Icons.notifications_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _levelColor(context);
    final timeLabel =
      '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_levelIcon(), color: levelColor, size: 20),
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
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        event.level.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: levelColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeLabel,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  event.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
