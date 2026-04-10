import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/mqtt/mqtt_config_service.dart';

class MqttSettingsPage extends StatefulWidget {
  const MqttSettingsPage({super.key});

  @override
  State<MqttSettingsPage> createState() => _MqttSettingsPageState();
}

class _MqttSettingsPageState extends State<MqttSettingsPage> {
  late final TextEditingController _brokerCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _topicCtrl;

  @override
  void initState() {
    super.initState();
    final config = getIt<MqttConfigService>().config;
    _brokerCtrl = TextEditingController(text: config.broker);
    _portCtrl = TextEditingController(text: config.port.toString());
    _topicCtrl = TextEditingController(text: config.baseTopic);
  }

  @override
  void dispose() {
    _brokerCtrl.dispose();
    _portCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
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
            FilledButton.icon(
              onPressed: () async {
                final port = int.tryParse(_portCtrl.text.trim()) ?? service.config.port;
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
          ],
        ),
      ),
    );
  }
}
