/// MQTT连接配置
class MqttConnectionConfig {
  final String broker;
  final int port;
  final String? username;
  final String? password;
  final String clientId;
  final int qos;
  final bool useWebSocket;
  final int keepAlive;
  final bool autoReconnect;
  final bool cleanSession;
  final int connectionTimeout;
  final String? willTopic;
  final String? willMessage;
  final int willQos;
  final bool willRetain;

  const MqttConnectionConfig({
    required this.broker,
    this.port = 1883,
    this.username,
    this.password,
    required this.clientId,
    this.qos = 1,
    this.useWebSocket = false,
    this.keepAlive = 60,
    this.autoReconnect = true,
    this.cleanSession = true,
    this.connectionTimeout = 10,
    this.willTopic,
    this.willMessage,
    this.willQos = 0,
    this.willRetain = false,
  });

  MqttConnectionConfig copyWith({
    String? broker,
    int? port,
    String? username,
    String? password,
    String? clientId,
    int? qos,
    bool? useWebSocket,
    int? keepAlive,
    bool? autoReconnect,
    bool? cleanSession,
    int? connectionTimeout,
    String? willTopic,
    String? willMessage,
    int? willQos,
    bool? willRetain,
  }) {
    return MqttConnectionConfig(
      broker: broker ?? this.broker,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      clientId: clientId ?? this.clientId,
      qos: qos ?? this.qos,
      useWebSocket: useWebSocket ?? this.useWebSocket,
      keepAlive: keepAlive ?? this.keepAlive,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      cleanSession: cleanSession ?? this.cleanSession,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      willTopic: willTopic ?? this.willTopic,
      willMessage: willMessage ?? this.willMessage,
      willQos: willQos ?? this.willQos,
      willRetain: willRetain ?? this.willRetain,
    );
  }

  Map<String, dynamic> toJson() => {
        'broker': broker,
        'port': port,
        'username': username,
        'password': password,
        'clientId': clientId,
        'qos': qos,
        'useWebSocket': useWebSocket,
        'keepAlive': keepAlive,
        'autoReconnect': autoReconnect,
        'cleanSession': cleanSession,
        'connectionTimeout': connectionTimeout,
        'willTopic': willTopic,
        'willMessage': willMessage,
        'willQos': willQos,
        'willRetain': willRetain,
      };

  factory MqttConnectionConfig.fromJson(Map<String, dynamic> json) {
    return MqttConnectionConfig(
      broker: json['broker'] as String,
      port: json['port'] as int? ?? 1883,
      username: json['username'] as String?,
      password: json['password'] as String?,
      clientId: json['clientId'] as String,
      qos: json['qos'] as int? ?? 1,
      useWebSocket: json['useWebSocket'] as bool? ?? false,
      keepAlive: json['keepAlive'] as int? ?? 60,
      autoReconnect: json['autoReconnect'] as bool? ?? true,
      cleanSession: json['cleanSession'] as bool? ?? true,
      connectionTimeout: json['connectionTimeout'] as int? ?? 10,
      willTopic: json['willTopic'] as String?,
      willMessage: json['willMessage'] as String?,
      willQos: json['willQos'] as int? ?? 0,
      willRetain: json['willRetain'] as bool? ?? false,
    );
  }
}

/// MQTT消息记录
class MqttMessageRecord {
  final String id;
  final String topic;
  final String payload;
  final DateTime timestamp;
  final bool isSent;
  final int qos;
  final bool retained;

  const MqttMessageRecord({
    required this.id,
    required this.topic,
    required this.payload,
    required this.timestamp,
    required this.isSent,
    this.qos = 1,
    this.retained = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
        'isSent': isSent,
        'qos': qos,
        'retained': retained,
      };

  factory MqttMessageRecord.fromJson(Map<String, dynamic> json) {
    return MqttMessageRecord(
      id: json['id'] as String,
      topic: json['topic'] as String,
      payload: json['payload'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSent: json['isSent'] as bool,
      qos: json['qos'] as int? ?? 1,
      retained: json['retained'] as bool? ?? false,
    );
  }
}
