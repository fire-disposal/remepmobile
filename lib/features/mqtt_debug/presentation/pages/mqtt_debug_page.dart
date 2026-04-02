import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/di/service_locator.dart';

import '../../../../core/widgets.dart';
import '../../data/models/mqtt_models.dart';
import '../controllers/mqtt_debug_controller.dart';

/// MQTT调试页面
class MqttDebugPage extends StatefulWidget {
  const MqttDebugPage({super.key});

  @override
  State<MqttDebugPage> createState() => _MqttDebugPageState();
}

class _MqttDebugPageState extends State<MqttDebugPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 连接配置
  final _brokerController = TextEditingController(text: 'iomt.205716.xyz');
  final _portController = TextEditingController(text: '1883');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _clientIdController =
      TextEditingController(text: 'debug_${DateTime.now().millisecondsSinceEpoch}');
  int _selectedQos = 1;
  bool _useWebSocket = false;

  // 消息构建
  final _topicController = TextEditingController();
  final _payloadController = TextEditingController(text: '{\n  \n}');
  int _messageQos = 1;
  bool _retainMessage = false;

  // 高级连接配置
  int _keepAlive = 60;
  bool _autoReconnect = true;
  bool _cleanSession = true;
  int _connectionTimeout = 10;
  final _willTopicController = TextEditingController();
  final _willMessageController = TextEditingController();
  int _willQos = 0;
  bool _willRetain = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadConfigFromController();
  }

  void _loadConfigFromController() {
    final controller = getIt<MqttDebugController>();
    final config = controller.cachedConfig;
    if (config != null) {
      _brokerController.text = config.broker;
      _portController.text = config.port.toString();
      _usernameController.text = config.username ?? '';
      _passwordController.text = config.password ?? '';
      _clientIdController.text = config.clientId;
      _selectedQos = config.qos;
      _useWebSocket = config.useWebSocket;
      _keepAlive = config.keepAlive;
      _autoReconnect = config.autoReconnect;
      _cleanSession = config.cleanSession;
      _connectionTimeout = config.connectionTimeout;
      _willTopicController.text = config.willTopic ?? '';
      _willMessageController.text = config.willMessage ?? '';
      _willQos = config.willQos;
      _willRetain = config.willRetain;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _brokerController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _clientIdController.dispose();
    _topicController.dispose();
    _payloadController.dispose();
    _willTopicController.dispose();
    _willMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MQTT调试工具'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.link), text: '连接'),
            Tab(icon: Icon(Icons.build), text: '构建'),
            Tab(icon: Icon(Icons.history), text: '历史'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConnectionTab(context),
          _buildBuilderTab(context),
          _buildHistoryTab(context),
        ],
      ),
    );
  }

  /// 连接配置Tab
  Widget _buildConnectionTab(BuildContext context) {
    return ListenableBuilder(
      listenable: getIt<MqttDebugController>(),
      builder: (context, _) {
        final controller = getIt<MqttDebugController>();
        final mqttState = controller.state;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 连接状态卡片
              _buildConnectionStatusCard(context, mqttState),
              const SizedBox(height: 24),

              // 连接配置
              Text(
                '连接配置',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _brokerController,
                decoration: const InputDecoration(
                  labelText: 'Broker地址',
                  hintText: '例如: iomt.205716.xyz',
                  prefixIcon: Icon(Icons.dns),
                  border: OutlineInputBorder(),
                ),
                enabled: !mqttState.isConnected,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: '端口',
                  hintText: '默认: 1883',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: !mqttState.isConnected,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: '用户名 (可选)',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      enabled: !mqttState.isConnected,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: '密码 (可选)',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      enabled: !mqttState.isConnected,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _clientIdController,
                decoration: const InputDecoration(
                  labelText: '客户端ID',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                enabled: !mqttState.isConnected,
              ),
              const SizedBox(height: 16),

              // QoS选择
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QoS级别',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('0')),
                        ButtonSegment(value: 1, label: Text('1')),
                        ButtonSegment(value: 2, label: Text('2')),
                      ],
                      selected: {_selectedQos},
                      onSelectionChanged: mqttState.isConnected
                          ? null
                          : (Set<int> selection) {
                              setState(() => _selectedQos = selection.first);
                            },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getQosDescription(_selectedQos),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // WebSocket选项
              SwitchListTile(
                title: const Text('使用WebSocket'),
                subtitle: const Text('通过WebSocket连接 (ws://)'),
                value: _useWebSocket,
                onChanged: mqttState.isConnected
                    ? null
                    : (value) => setState(() => _useWebSocket = value),
              ),
              const SizedBox(height: 16),

              // KeepAlive 和连接超时
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: _keepAlive.toString()),
                      decoration: const InputDecoration(
                        labelText: '保活间隔 (秒)',
                        prefixIcon: Icon(Icons.timer),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !mqttState.isConnected,
                      onChanged: (value) {
                        _keepAlive = int.tryParse(value) ?? 60;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: _connectionTimeout.toString()),
                      decoration: const InputDecoration(
                        labelText: '超时 (秒)',
                        prefixIcon: Icon(Icons.timelapse),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !mqttState.isConnected,
                      onChanged: (value) {
                        _connectionTimeout = int.tryParse(value) ?? 10;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 连接行为选项
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      title: const Text('自动重连'),
                      value: _autoReconnect,
                      onChanged: mqttState.isConnected
                          ? null
                          : (value) => setState(() => _autoReconnect = value),
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      title: const Text('清除会话'),
                      value: _cleanSession,
                      onChanged: mqttState.isConnected
                          ? null
                          : (value) => setState(() => _cleanSession = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 遗嘱消息 (高级)
              ExpansionTile(
                title: const Text('遗嘱消息 (高级)'),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _willTopicController,
                          decoration: const InputDecoration(
                            labelText: '遗嘱主题',
                            prefixIcon: Icon(Icons.topic),
                            border: OutlineInputBorder(),
                          ),
                          enabled: !mqttState.isConnected,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _willMessageController,
                          decoration: const InputDecoration(
                            labelText: '遗嘱消息',
                            prefixIcon: Icon(Icons.message),
                            border: OutlineInputBorder(),
                          ),
                          enabled: !mqttState.isConnected,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('遗嘱QoS', style: Theme.of(context).textTheme.bodySmall),
                                    DropdownButton<int>(
                                      value: _willQos,
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      items: const [
                                        DropdownMenuItem(value: 0, child: Text('0')),
                                        DropdownMenuItem(value: 1, child: Text('1')),
                                        DropdownMenuItem(value: 2, child: Text('2')),
                                      ],
                                      onChanged: mqttState.isConnected
                                          ? null
                                          : (value) {
                                              if (value != null) {
                                                setState(() => _willQos = value);
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _willRetain,
                                      onChanged: mqttState.isConnected
                                          ? null
                                          : (value) {
                                              setState(() => _willRetain = value ?? false);
                                            },
                                    ),
                                    const Text('保留遗嘱'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 连接/断开按钮
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _toggleConnection(controller, mqttState),
                  icon: Icon(
                    mqttState.isConnected ? Icons.link_off : Icons.link,
                  ),
                  label: Text(
                    mqttState.isConnected ? '断开连接' : '连接',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: mqttState.isConnected
                        ? Theme.of(context).colorScheme.error
                        : null,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              // 错误提示
              if (mqttState.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          mqttState.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: controller.clearError,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 消息构建Tab
  Widget _buildBuilderTab(BuildContext context) {
    return ListenableBuilder(
      listenable: getIt<MqttDebugController>(),
      builder: (context, _) {
        final controller = getIt<MqttDebugController>();
        final mqttState = controller.state;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 快捷主题
              Text(
                '快捷主题',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickTopicChip(
                    context,
                    'remipedia/{sn}/event',
                    '跌倒事件',
                  ),
                  _buildQuickTopicChip(
                    context,
                    'remipedia/{sn}/data',
                    '设备数据',
                  ),
                  _buildQuickTopicChip(
                    context,
                    'test/message',
                    '测试消息',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 主题输入
              TextField(
                controller: _topicController,
                decoration: const InputDecoration(
                  labelText: '主题',
                  hintText: '例如: remipedia/DEVICE_001/event',
                  prefixIcon: Icon(Icons.topic),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 消息选项
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('QoS', style: Theme.of(context).textTheme.bodySmall),
                          DropdownButton<int>(
                            value: _messageQos,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('0 - 最多一次')),
                              DropdownMenuItem(value: 1, child: Text('1 - 至少一次')),
                              DropdownMenuItem(value: 2, child: Text('2 - 恰好一次')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _messageQos = value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _retainMessage,
                            onChanged: (value) {
                              setState(() => _retainMessage = value ?? false);
                            },
                          ),
                          const Text('保留消息'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 消息体
              Text(
                '消息体 (JSON)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.code, size: 18),
                          const SizedBox(width: 8),
                          const Text('JSON编辑器'),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.format_align_left, size: 18),
                            label: const Text('格式化'),
                            onPressed: _formatJson,
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.clear, size: 18),
                            label: const Text('清空'),
                            onPressed: () {
                              _payloadController.clear();
                            },
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _payloadController,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        hintText: '{\n  "key": "value"\n}',
                      ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 发送按钮
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: mqttState.isConnected
                      ? () => _sendMessage(controller)
                      : null,
                  icon: const Icon(Icons.send),
                  label: const Text('发送消息'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 消息历史Tab
  Widget _buildHistoryTab(BuildContext context) {
    return ListenableBuilder(
      listenable: getIt<MqttDebugController>(),
      builder: (context, _) {
        final controller = getIt<MqttDebugController>();
        final messages = controller.state.messageHistory;

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无消息记录',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '发送或接收的消息将显示在这里',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // 工具栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  Text(
                    '${messages.length} 条消息',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('清空'),
                    onPressed: controller.clearHistory,
                  ),
                ],
              ),
            ),

            // 消息列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return _buildMessageCard(context, message)
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: index * 50))
                      .slideX(begin: 0.1);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectionStatusCard(BuildContext context, MqttDebugState mqttState) {
    final isConnected = mqttState.isConnected;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isConnected
              ? [const Color(0xFF43A047), const Color(0xFF66BB6A)]
              : [const Color(0xFF607D8B), const Color(0xFF78909C)],
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
              isConnected ? Icons.cloud_done : Icons.cloud_off,
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
                  isConnected
                      ? '${mqttState.config?.broker}:${mqttState.config?.port}'
                      : '配置连接参数后点击连接',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ).animate(onPlay: (controller) => controller.repeat()).fadeIn(
                        duration: 1000.ms,
                      ),
                  const SizedBox(width: 8),
                  const Text(
                    '在线',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildQuickTopicChip(BuildContext context, String topic, String label) {
    return ActionChip(
      avatar: const Icon(Icons.topic, size: 18),
      label: Text(label),
      onPressed: () {
        _topicController.text = topic;
        Toast.info(context, '已选择主题: $topic');
      },
    );
  }

  Widget _buildMessageCard(BuildContext context, MqttMessageRecord message) {
    final isSent = message.isSent;

    return ModernCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSent
                      ? const Color(0xFF1E88E5).withValues(alpha: 0.1)
                      : const Color(0xFF43A047).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSent ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: isSent
                          ? const Color(0xFF1E88E5)
                          : const Color(0xFF43A047),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSent ? '发送' : '接收',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSent
                            ? const Color(0xFF1E88E5)
                            : const Color(0xFF43A047),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.topic,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatTime(message.timestamp),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 消息内容
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message.payload,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getQosDescription(int qos) {
    switch (qos) {
      case 0:
        return '最多一次 - 消息可能丢失';
      case 1:
        return '至少一次 - 消息可能重复';
      case 2:
        return '恰好一次 - 消息不丢失不重复';
      default:
        return '';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  void _formatJson() {
    try {
      final json = jsonDecode(_payloadController.text);
      _payloadController.text = const JsonEncoder.withIndent('  ').convert(json);
    } catch (e) {
      Toast.error(context, 'JSON格式错误');
    }
  }

  Future<void> _toggleConnection(
    MqttDebugController controller,
    MqttDebugState mqttState,
  ) async {
    if (mqttState.isConnected) {
      await controller.disconnect();
      if (mounted) Toast.success(context, '已断开连接');
    } else {
      final config = MqttConnectionConfig(
        broker: _brokerController.text,
        port: int.tryParse(_portController.text) ?? 1883,
        username: _usernameController.text.isEmpty ? null : _usernameController.text,
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
        clientId: _clientIdController.text,
        qos: _selectedQos,
        useWebSocket: _useWebSocket,
        keepAlive: _keepAlive,
        autoReconnect: _autoReconnect,
        cleanSession: _cleanSession,
        connectionTimeout: _connectionTimeout,
        willTopic: _willTopicController.text.isEmpty ? null : _willTopicController.text,
        willMessage: _willMessageController.text.isEmpty ? null : _willMessageController.text,
        willQos: _willQos,
        willRetain: _willRetain,
      );

      final success = await controller.connect(config);
      if (mounted) {
        if (success) {
          Toast.success(context, '连接成功');
        } else {
          Toast.error(context, '连接失败');
        }
      }
    }
  }

  Future<void> _sendMessage(MqttDebugController controller) async {
    if (_topicController.text.isEmpty) {
      Toast.error(context, '请输入主题');
      return;
    }

    final success = await controller.publish(
      topic: _topicController.text,
      payload: _payloadController.text,
      qos: _messageQos,
      retain: _retainMessage,
    );

    if (mounted) {
      if (success) {
        Toast.success(context, '消息已发送');
      } else {
        Toast.error(context, '发送失败');
      }
    }
  }
}