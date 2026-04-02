import '../../../../core/mqtt/mqtt_service.dart';
import '../models/fall_detection_models.dart';

class FallDetectorService {
  FallDetectorService(this._mqttService);

  final MqttService _mqttService;

  bool get isConnected => _mqttService.currentStatus == MqttConnectionStatus.connected;

  Future<bool> sendEvent(FallEventPayload payload) async {
    if (!isConnected) return false;

    try {
      _mqttService.publish(
        topic: 'remipedia/${payload.serialNumber}/event',
        message: payload.toJsonString(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
