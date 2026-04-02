import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/widgets.dart';
import '../../../../features/mqtt_debug/presentation/controllers/mqtt_debug_controller.dart';
import '../../data/models/fall_detection_models.dart';
import '../controllers/fall_detector_controller.dart';

/// 跌倒检测模拟器页面
class FallDetectorPage extends StatefulWidget {
  const FallDetectorPage({super.key});

  @override
  State<FallDetectorPage> createState() => _FallDetectorPageState();
}

class _FallDetectorPageState extends State<FallDetectorPage> {
  final _serialNumberController = TextEditingController(text: 'DEVICE_001');
  final _confidenceController = TextEditingController(text: '0.85');

  FallEventType _selectedEventType = FallEventType.personFall;
  DeviceType _selectedDeviceType = DeviceType.fallDetector;
  bool _autoTimestamp = true;
  int _autoSendInterval = 5;

  @override
  void dispose() {
    _serialNumberController.dispose();
    _confidenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('跌倒检测模拟器'),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: getIt<FallDetectorController>(),
        builder: (context, _) {
          final controller = getIt<FallDetectorController>();
          final state = controller.state;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 连接状态卡片
                _buildConnectionStatusCard(context, state),
                const SizedBox(height: 24),

                // 设备配置
                Text(
                  '设备配置',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildDeviceConfigSection(context),
                const SizedBox(height: 24),

                // 跌倒事件模拟
                Text(
                  '跌倒事件模拟',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildFallEventSection(context, controller, state),
                const SizedBox(height: 24),

                // 设备数据模拟
                Text(
                  '设备数据模拟',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildDeviceDataSection(context, controller, state),
                const SizedBox(height: 24),

                // 发送统计
                _buildStatisticsCard(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatusCard(BuildContext context, FallDetectorState state) {
    final isConnected = state.isConnected;
    final mqttConfig = getIt<MqttDebugController>().cachedConfig;
    final subtitle = isConnected
        ? (mqttConfig != null
            ? '${mqttConfig.broker}:${mqttConfig.port}'
            : '可以发送模拟事件')
        : (mqttConfig != null && mqttConfig.broker.isNotEmpty
            ? '未连接至 ${mqttConfig.broker}:${mqttConfig.port}'
            : '请先配置并连接MQTT服务器');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isConnected
              ? [const Color(0xFF43A047), const Color(0xFF66BB6A)]
              : [const Color(0xFFE53935), const Color(0xFFEF5350)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected ? Icons.link : Icons.link_off,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? '已连接' : '未连接',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (!isConnected)
            FilledButton.icon(
              onPressed: () => context.go('/app/mqtt-debug'),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('去连接'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE53935),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildDeviceConfigSection(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _serialNumberController,
          decoration: const InputDecoration(
            labelText: '设备序列号',
            hintText: '输入设备唯一标识',
            prefixIcon: Icon(Icons.devices),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                title: const Text('自动时间戳'),
                subtitle: const Text('使用当前时间'),
                value: _autoTimestamp,
                onChanged: (value) {
                  setState(() => _autoTimestamp = value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFallEventSection(
    BuildContext context,
    FallDetectorController controller,
    FallDetectorState state,
  ) {
    return Column(
      children: [
        // 事件类型选择
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '事件类型',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FallEventType.values.map((type) {
                  final isSelected = _selectedEventType == type;
                  return ChoiceChip(
                    label: Text(type.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedEventType = type);
                      }
                    },
                    selectedColor: const Color(0xFFE53935).withValues(alpha: 0.2),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 置信度设置
        if (_selectedEventType == FallEventType.personFall) ...[
          TextField(
            controller: _confidenceController,
            decoration: const InputDecoration(
              labelText: '置信度 (0.0 - 1.0)',
              hintText: '跌倒检测需要 ≥ 0.5',
              prefixIcon: Icon(Icons.percent),
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
        ],

        // 预览消息
        _buildMessagePreview(context, isFallEvent: true),

        const SizedBox(height: 16),

        // 发送按钮
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: state.isConnected && !state.isSending
                    ? () => _sendFallEvent(controller)
                    : null,
                icon: state.isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(state.isSending ? '发送中...' : '发送事件'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 自动发送控制
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.autorenew, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('自动发送模式'),
                  ),
                  Switch(
                    value: controller.isAutoSendEnabled,
                    onChanged: state.isConnected
                        ? (value) {
                            if (value) {
                              _startAutoSend(controller);
                            } else {
                              controller.stopAutoSend();
                            }
                          }
                        : null,
                  ),
                ],
              ),
              if (controller.isAutoSendEnabled) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('间隔: '),
                    Expanded(
                      child: Slider(
                        value: _autoSendInterval.toDouble(),
                        min: 1,
                        max: 60,
                        divisions: 59,
                        label: '$_autoSendInterval 秒',
                        onChanged: (value) {
                          setState(() => _autoSendInterval = value.round());
                        },
                      ),
                    ),
                    Text('$_autoSendInterval 秒'),
                  ],
                ),
                Text(
                  '已自动发送 ${state.statistics.autoSendCount} 条消息',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceDataSection(
    BuildContext context,
    FallDetectorController controller,
    FallDetectorState state,
  ) {
    return Column(
      children: [
        // 设备类型选择
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '设备类型',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DeviceType.values.map((type) {
                  final isSelected = _selectedDeviceType == type;
                  return ChoiceChip(
                    label: Text(type.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedDeviceType = type);
                      }
                    },
                    selectedColor: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 预览消息
        _buildMessagePreview(context, isFallEvent: false),

        const SizedBox(height: 16),

        // 发送按钮
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.isConnected
                    ? () => _sendDeviceData(controller)
                    : null,
                icon: const Icon(Icons.dataset),
                label: const Text('发送设备数据'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E88E5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessagePreview(BuildContext context, {required bool isFallEvent}) {
    final preview = _generatePreviewMessage(isFallEvent);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.code,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '消息预览',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              preview,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _generatePreviewMessage(bool isFallEvent) {
    if (isFallEvent) {
      final confidence = double.tryParse(_confidenceController.text) ?? 0.85;
      final message = FallDetectionMessage(
        eventType: _selectedEventType.value,
        confidence: confidence.clamp(0.0, 1.0),
        timestamp: _autoTimestamp
            ? DateTime.now().toUtc().toIso8601String()
            : null,
      );
      return message.toJsonString();
    } else {
      final data = _generateMockData(_selectedDeviceType);
      final message = DeviceDataMessage(
        deviceType: _selectedDeviceType.value,
        timestamp: _autoTimestamp
            ? DateTime.now().toUtc().toIso8601String()
            : null,
        data: data,
      );
      return message.toJsonString();
    }
  }

  List<int> _generateMockData(DeviceType type) {
    switch (type) {
      case DeviceType.heartRateMonitor:
        return [72, 75, 78, 73, 76];
      case DeviceType.spo2Sensor:
        return [98, 97, 99, 98, 97];
      case DeviceType.smartWatch:
        return [8500, 72, 98, 120, 80];
      case DeviceType.fallDetector:
        return [10, 20, 30, 40, 50, 60];
    }
  }

  Widget _buildStatisticsCard(BuildContext context, FallDetectorState state) {
    return ModernCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                icon: Icons.send,
                label: '手动发送',
                value: state.statistics.manualSendCount.toString(),
                color: const Color(0xFF1E88E5),
              ),
              _buildStatItem(
                context,
                icon: Icons.autorenew,
                label: '自动发送',
                value: state.statistics.autoSendCount.toString(),
                color: const Color(0xFF43A047),
              ),
              _buildStatItem(
                context,
                icon: Icons.devices,
                label: '设备ID',
                value: _serialNumberController.text,
                color: const Color(0xFF7B1FA2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _sendFallEvent(FallDetectorController controller) async {
    final confidence = double.tryParse(_confidenceController.text) ?? 0.85;
    final success = await controller.sendFallEvent(
      serialNumber: _serialNumberController.text,
      eventType: _selectedEventType,
      confidence: confidence,
      autoTimestamp: _autoTimestamp,
    );

    if (mounted) {
      if (success) {
        Toast.success(context, '事件已发送');
      } else {
        Toast.error(context, controller.state.error ?? '发送失败');
      }
    }
  }

  Future<void> _sendDeviceData(FallDetectorController controller) async {
    final success = await controller.sendDeviceData(
      serialNumber: _serialNumberController.text,
      deviceType: _selectedDeviceType,
      autoTimestamp: _autoTimestamp,
    );

    if (mounted) {
      if (success) {
        Toast.success(context, '设备数据已发送');
      } else {
        Toast.error(context, controller.state.error ?? '发送失败');
      }
    }
  }

  void _startAutoSend(FallDetectorController controller) {
    final confidence = double.tryParse(_confidenceController.text) ?? 0.85;
    controller.startAutoSend(
      serialNumber: _serialNumberController.text,
      eventType: _selectedEventType,
      confidence: confidence,
      intervalSeconds: _autoSendInterval,
    );
  }
}