import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 环境配置
class EnvConstants {
  EnvConstants._();

  static String get appName => dotenv.get('APP_NAME', fallback: 'ReMep Mobile');
  static String get apiBaseUrl => dotenv.get('API_BASE_URL', fallback: '');
  static int get apiTimeout => int.tryParse(dotenv.get('API_TIMEOUT', fallback: '30000')) ?? 30000;
  static String get mqttBrokerUrl => dotenv.get('MQTT_BROKER_URL', fallback: '');
  static int get mqttPort => int.tryParse(dotenv.get('MQTT_PORT', fallback: '1883')) ?? 1883;
  static bool get debugMode => dotenv.get('DEBUG_MODE', fallback: 'false') == 'true';

  static bool get isProduction => !debugMode;
  static bool get isDevelopment => debugMode;
}