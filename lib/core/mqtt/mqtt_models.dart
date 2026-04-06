class MqttConnectionConfig {
  final String broker;
  final int port;
  final String clientId;
  final int keepAlive;
  final bool autoReconnect;
  final bool useWebSocket;
  final String? username;
  final String? password;
  final int qos;
  final bool cleanSession;
  final String? willTopic;
  final String? willMessage;
  final int willQos;
  final bool willRetain;
  final int connectionTimeout;

  const MqttConnectionConfig({
    required this.broker,
    required this.port,
    required this.clientId,
    this.keepAlive = 20,
    this.autoReconnect = true,
    this.useWebSocket = false,
    this.username,
    this.password,
    this.qos = 1,
    this.cleanSession = true,
    this.willTopic,
    this.willMessage,
    this.willQos = 1,
    this.willRetain = false,
    this.connectionTimeout = 15,
  });
}
