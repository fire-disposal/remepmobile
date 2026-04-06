import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/services/imu_detection_dev_service.dart';

class ImuFallDetectionPage extends StatefulWidget {
  const ImuFallDetectionPage({super.key});

  @override
  State<ImuFallDetectionPage> createState() => _ImuFallDetectionPageState();
}

class _ImuFallDetectionPageState extends State<ImuFallDetectionPage> {
  final ImuDetectionDevService _service = ImuDetectionDevService();

  final List<ImuSample> _samples = [];
  StreamSubscription<ImuSample>? _subscription;

  double _threshold = ImuDetectionDevService.defaultThreshold;
  bool _streaming = false;

  void _appendSample(ImuSample sample) {
    setState(() {
      _samples.insert(0, sample);
      if (_samples.length > 40) {
        _samples.removeRange(40, _samples.length);
      }
    });
  }

  void _sampleOnce() {
    _appendSample(_service.mockSample(threshold: _threshold));
  }

  void _startStreaming() {
    _subscription?.cancel();
    _subscription = _service.accelerometerStream(threshold: _threshold).listen(_appendSample);
    setState(() => _streaming = true);
  }

  void _stopStreaming() {
    _subscription?.cancel();
    _subscription = null;
    setState(() => _streaming = false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IMU 跌倒检测')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IMU 依赖与运行模式', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      Chip(label: Text('sensors_plus ✓')),
                      Chip(label: Text('permission_handler ✓')),
                      Chip(label: Text('阈值策略 ✓')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '安装建议：flutter pub add sensors_plus permission_handler',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('跌倒阈值:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: _threshold,
                          min: 1.6,
                          max: 4,
                          divisions: 12,
                          label: _threshold.toStringAsFixed(2),
                          onChanged: (v) => setState(() => _threshold = v),
                        ),
                      ),
                      Text(_threshold.toStringAsFixed(2)),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(onPressed: _sampleOnce, child: const Text('Mock 采样一次')),
                      FilledButton.tonal(
                        onPressed: _streaming ? null : _startStreaming,
                        child: const Text('开始实时流'),
                      ),
                      OutlinedButton(
                        onPressed: _streaming ? _stopStreaming : null,
                        child: const Text('停止实时流'),
                      ),
                      Chip(label: Text(_streaming ? '实时中' : '已停止')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: _samples.isEmpty
                ? const SizedBox(
                    height: 120,
                    child: Center(child: Text('暂无采样数据')),
                  )
                : ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _samples.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = _samples[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          'a=(${s.ax.toStringAsFixed(2)}, ${s.ay.toStringAsFixed(2)}, ${s.az.toStringAsFixed(2)})  intensity=${s.intensity.toStringAsFixed(2)}',
                        ),
                        subtitle: Text(s.timestamp.toIso8601String()),
                        trailing: Text(
                          s.isFallSuspected ? '疑似跌倒' : '正常',
                          style: TextStyle(
                            color: s.isFallSuspected ? Theme.of(context).colorScheme.error : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
