import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/mqtt/mqtt_config_service.dart';
import 'mqtt_history_page.dart';

class MqttSettingsPage extends StatefulWidget {
  const MqttSettingsPage({super.key});

  @override
  State<MqttSettingsPage> createState() => _MqttSettingsPageState();
}

class _MqttSettingsPageState extends State<MqttSettingsPage> {
  late final TextEditingController _brokerCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _topicCtrl;
  String _previewUri = '';
  String _previewTopic = '';

  @override
  void initState() {
    super.initState();
    final config = getIt<MqttConfigService>().config;
    _brokerCtrl = TextEditingController(text: config.broker);
    _portCtrl = TextEditingController(text: config.port.toString());
    _topicCtrl = TextEditingController(text: config.baseTopic);
    _refreshPreview();
    _brokerCtrl.addListener(_refreshPreview);
    _portCtrl.addListener(_refreshPreview);
    _topicCtrl.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _brokerCtrl.removeListener(_refreshPreview);
    _portCtrl.removeListener(_refreshPreview);
    _topicCtrl.removeListener(_refreshPreview);
    _brokerCtrl.dispose();
    _portCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    final service = getIt<MqttConfigService>();
    final port = int.tryParse(_portCtrl.text.trim()) ?? service.config.port;
    _previewUri = service.buildPreviewUri(
      broker: _brokerCtrl.text.trim(),
      port: port,
    );
    final baseTopic = _topicCtrl.text.trim().isEmpty
        ? service.config.baseTopic
        : _topicCtrl.text.trim();
    _previewTopic = '$baseTopic/diagnostics/test';
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = getIt<MqttConfigService>();
    return Scaffold(
      appBar: AppBar(title: const Text('MQTT 全局配置')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _brokerCtrl,
              decoration: const InputDecoration(labelText: 'Broker 地址'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Port'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topicCtrl,
              decoration: const InputDecoration(labelText: '全局 Topic 前缀'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('预览地址', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Text(_previewUri.isEmpty ? '-' : _previewUri),
                  const SizedBox(height: 8),
                  Text('测试 Topic', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Text(_previewTopic.isEmpty ? '-' : _previewTopic),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final port = int.tryParse(_portCtrl.text.trim()) ?? service.config.port;
                      final message = service.validateConfig(
                        broker: _brokerCtrl.text.trim(),
                        port: port,
                        baseTopic: _topicCtrl.text.trim(),
                      );
                      final text = message ?? '配置解析成功';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(text)),
                      );
                    },
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('测试解析'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final ok = service.publishTest();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? '测试包已发送' : 'MQTT 未连接')),
                      );
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('发送测试包'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final port = int.tryParse(_portCtrl.text.trim()) ?? service.config.port;
                final validation = service.validateConfig(
                  broker: _brokerCtrl.text.trim(),
                  port: port,
                  baseTopic: _topicCtrl.text.trim(),
                );
                if (validation != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(validation)),
                  );
                  return;
                }
                await service.updateConfig(
                  broker: _brokerCtrl.text.trim(),
                  port: port,
                  baseTopic: _topicCtrl.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('MQTT 全局配置已更新')),
                  );
                }
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存并重连'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MqttHistoryPage()),
                );
              },
              icon: const Icon(Icons.history_rounded),
              label: const Text('查看发送历史'),
            ),
          ],
        ),
      ),
    );
  }
}
