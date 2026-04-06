import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class BluetoothDebugPage extends StatefulWidget {
  const BluetoothDebugPage({super.key});

  @override
  State<BluetoothDebugPage> createState() => _BluetoothDebugPageState();
}

class _BluetoothDebugPageState extends State<BluetoothDebugPage> {
  final _random = Random();
  Timer? _timer;
  final List<String> _received = [];

  void _startReceiving() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      final bytes = List<int>.generate(6, (_) => _random.nextInt(255));
      setState(() {
        _received.insert(0, '${DateTime.now().toIso8601String()}  RX: ${bytes.join(' ')}');
        if (_received.length > 40) {
          _received.removeRange(40, _received.length);
        }
      });
    });
    setState(() {});
  }

  void _stopReceiving() {
    _timer?.cancel();
    _timer = null;
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('蓝牙数据接收调试')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              children: [
                FilledButton(onPressed: _startReceiving, child: const Text('开始接收')),
                OutlinedButton(onPressed: _stopReceiving, child: const Text('停止接收')),
                Chip(label: Text(_timer == null ? '状态：空闲' : '状态：接收中')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: ListView.separated(
                  itemCount: _received.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(_received[i], style: const TextStyle(fontFamily: 'monospace')),
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
