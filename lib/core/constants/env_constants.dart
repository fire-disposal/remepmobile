import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 环境配置
class EnvConstants {
  EnvConstants._();

  static String get appName => dotenv.env['APP_NAME'] ?? 'ReMep Mobile';
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';
  static int get apiTimeout => int.tryParse(dotenv.env['API_TIMEOUT'] ?? '30000') ?? 30000;
  static String get mqttBrokerUrl => dotenv.env['MQTT_BROKER_URL'] ?? '';
  static int get mqttPort => int.tryParse(dotenv.env['MQTT_PORT'] ?? '1883') ?? 1883;
  static bool get debugMode => dotenv.env['DEBUG_MODE'] == 'true';

  static bool get isProduction => !debugMode;
  static bool get isDevelopment => debugMode;
}