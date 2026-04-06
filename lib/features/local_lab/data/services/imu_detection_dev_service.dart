import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class ImuSample {
  const ImuSample({
    required this.ax,
    required this.ay,
    required this.az,
    required this.intensity,
    required this.isFallSuspected,
    required this.timestamp,
  });

  final double ax;
  final double ay;
  final double az;
  final double intensity;
  final bool isFallSuspected;
  final DateTime timestamp;
}

/// IMU 跌倒检测开发服务。
///
/// 默认接入 sensors_plus 的加速度流，若无实时流则可回退到 mock 采样。
class ImuDetectionDevService {
  static const double defaultThreshold = 2.6;

  Stream<ImuSample> accelerometerStream({double threshold = defaultThreshold}) {
    return accelerometerEventStream().map((event) {
      final intensity = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      return ImuSample(
        ax: event.x,
        ay: event.y,
        az: event.z,
        intensity: intensity,
        isFallSuspected: intensity > threshold,
        timestamp: DateTime.now(),
      );
    });
  }

  ImuSample mockSample({double threshold = defaultThreshold}) {
    final random = Random();
    final ax = (random.nextDouble() * 4) - 2;
    final ay = (random.nextDouble() * 4) - 2;
    final az = (random.nextDouble() * 4) - 2;
    final intensity = sqrt(ax * ax + ay * ay + az * az);

    return ImuSample(
      ax: ax,
      ay: ay,
      az: az,
      intensity: intensity,
      isFallSuspected: intensity > threshold,
      timestamp: DateTime.now(),
    );
  }
}
