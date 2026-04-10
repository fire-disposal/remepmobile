import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di/service_locator.dart';
import '../../core/mqtt/mqtt_config_service.dart';

class MqttHistoryPage extends StatefulWidget {
  const MqttHistoryPage({super.key});

  @override
  State<MqttHistoryPage> createState() => _MqttHistoryPageState();
}

class _MqttHistoryPageState extends State<MqttHistoryPage> {
  late final MqttConfigService _service;

  @override
  void initState() {
    super.initState();
    _service = getIt<MqttConfigService>();
    _service.addListener(_onService);
  }

  void _onService() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onService);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _service.getPublishHistory();
    return Scaffold(
      appBar: AppBar(
        title: const Text('MQTT 发送历史'),
        actions: [
          IconButton(
            tooltip: '清空历史',
            onPressed: items.isEmpty
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认清空'),
                        content: const Text('确定要清空所有发送历史吗？此操作不可恢复。'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await _service.clearPublishHistory();
                    }
                  },
            icon: const Icon(Icons.delete_outline),
          )
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('暂无发送历史'))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final it = items[i];
                final topic = it['topic'] as String? ?? '-';
                final payload = it['payload'] as String? ?? '';
                final ts = it['ts'] as String? ?? '';
                final qos = it['qos']?.toString() ?? '0';
                return ListTile(
                  title: Text(topic, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$ts · QoS:$qos', style: Theme.of(context).textTheme.bodySmall),
                  onTap: () => _showDetail(topic, payload, ts, qos),
                );
              },
            ),
    );
  }

  void _showDetail(String topic, String payload, String ts, String qos) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(topic, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('时间：$ts'),
              const SizedBox(height: 8),
              Text('QoS：$qos'),
              const SizedBox(height: 12),
              SelectableText(payload),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: payload));
              Navigator.pop(ctx);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
            },
            child: const Text('复制内容'),
          ),
        ],
      ),
    );
  }
}
