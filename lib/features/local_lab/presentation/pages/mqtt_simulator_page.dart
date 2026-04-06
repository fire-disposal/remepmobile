import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class MqttSimulatorPage extends StatefulWidget {
  const MqttSimulatorPage({super.key});

  @override
  State<MqttSimulatorPage> createState() => _MqttSimulatorPageState();
}

class _MqttSimulatorPageState extends State<MqttSimulatorPage> {
  final _random = Random();
  final _topicController = TextEditingController(text: 'local/device/fall');

  Timer? _timer;
  final List<String> _logs = [];
  int _intervalSeconds = 2;


  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: _intervalSeconds), (_) {
      final payload = '{\"risk\": ${(_random.nextDouble() * 100).toStringAsFixed(2)}, \"ts\": \"${DateTime.now().toIso8601String()}\"}';
      final topic = _topicController.text.trim().isEmpty ? 'local/device/fall' : _topicController.text.trim();
      setState(() {
        _logs.insert(0, '[$topic] $payload');
        if (_logs.length > 30) {
          _logs.removeRange(30, _logs.length);
        }
      });
    });
    setState(() {});
  }

  void _stop() {
    _timer?.cancel();
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MQTT 数据模拟')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _topicController,
                    decoration: const InputDecoration(labelText: '主题 Topic'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    initialValue: _intervalSeconds,
                    items: const [1, 2, 3, 5]
                        .map((it) => DropdownMenuItem(value: it, child: Text('${it}s')))
                        .toList(),
                    onChanged: (v) => _intervalSeconds = v ?? 2,
                    decoration: const InputDecoration(labelText: '频率'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _start, child: const Text('开始')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _stop, child: const Text('停止')),
              ],
            ),
            const SizedBox(height: 16),
            Text(_timer == null ? '状态：空闲' : '状态：模拟中'),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: ListView.separated(
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) => ListTile(
                    dense: true,
                    title: Text(_logs[index], style: const TextStyle(fontFamily: 'monospace')),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
