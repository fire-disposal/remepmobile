import 'package:flutter/foundation.dart';

enum AppEventSource { imu, vision, system }

enum AppEventLevel { info, warning, critical }

@immutable
class AppEvent {
  const AppEvent({
    required this.id,
    required this.source,
    required this.level,
    required this.title,
    required this.message,
    required this.timestamp,
    this.payload = const <String, dynamic>{},
  });

  final String id;
  final AppEventSource source;
  final AppEventLevel level;
  final String title;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  String get sourceLabel {
    switch (source) {
      case AppEventSource.imu:
        return 'IMU';
      case AppEventSource.vision:
        return '视觉';
      case AppEventSource.system:
        return '系统';
    }
  }
}
