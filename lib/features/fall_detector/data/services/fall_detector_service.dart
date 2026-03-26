import '../../../../core/mqtt/mqtt_service.dart';
import '../models/fall_detection_models.dart';

/// 跌倒检测服务
/// 提供跌倒事件模拟和数据发送功能
class FallDetectorService {
  final MqttService _mqttService;

  FallDetectorService(this._mqttService);

  /// 检查是否已连接
  bool get isConnected =>
      _mqttService.currentStatus == MqttConnectionStatus.connected;

  /// 发送跌倒检测事件
  Future<bool> sendFallEvent({
    required String serialNumber,
    required FallDetectionMessage message,
    int qos = 1,
  }) async {
    if (!isConnected) {
      return false;
    }

    try {
      final topic = 'remipedia/$serialNumber/event';
      _mqttService.publish(
        topic: topic,
        message: message.toJsonString(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 发送设备数据
  Future<bool> sendDeviceData({
    required String serialNumber,
    required DeviceDataMessage message,
    int qos = 1,
  }) async {
    if (!isConnected) {
      return false;
    }

    try {
      final topic = 'remipedia/$serialNumber/data';
      _mqttService.publish(
        topic: topic,
        message: message.toJsonString(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 生成模拟设备数据
  List<int> generateMockData(DeviceType type) {
    switch (type) {
      case DeviceType.heartRateMonitor:
        // 心率数据: 60-100 bpm
        return [72, 75, 78, 73, 76];
      case DeviceType.spo2Sensor:
        // 血氧数据: 95-100%
        return [98, 97, 99, 98, 97];
      case DeviceType.smartWatch:
        // 智能手表: 步数、心率、血氧
        return [8500, 72, 98, 120, 80];
      case DeviceType.fallDetector:
        // 跌倒检测器: 加速度数据
        return [10, 20, 30, 40, 50, 60];
    }
  }
}