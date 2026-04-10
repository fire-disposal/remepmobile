import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

import '../../core/utils/logger.dart';
import 'package:sensors_plus/sensors_plus.dart' as sensors;

/// IMU传感器数据模型
class IMUSensorData {
  final DateTime timestamp;
  
  // 加速度计数据 (m/s²)
  final double accelX;
  final double accelY;
  final double accelZ;
  
  // 陀螺仪数据 (rad/s)
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  
  // 磁力计数据 (μT) - 可能为null如果设备不支持
  final double? magX;
  final double? magY;
  final double? magZ;

  // 计算属性
  double get accelMagnitude => math.sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);
  double get gyroMagnitude => math.sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);
  
  // 俯仰角 (Pitch) - 绕X轴旋转
  double get pitch => math.atan2(accelY, math.sqrt(accelX * accelX + accelZ * accelZ));
  
  // 横滚角 (Roll) - 绕Y轴旋转  
  double get roll => math.atan2(-accelX, accelZ);

  IMUSensorData({
    required this.timestamp,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    this.magX,
    this.magY,
    this.magZ,
  });

  factory IMUSensorData.fromSensors({
    required AccelerometerEvent accel,
    required GyroscopeEvent gyro,
    MagnetometerEvent? mag,
  }) {
    return IMUSensorData(
      timestamp: DateTime.now(),
      accelX: accel.x,
      accelY: accel.y,
      accelZ: accel.z,
      gyroX: gyro.x,
      gyroY: gyro.y,
      gyroZ: gyro.z,
      magX: mag?.x,
      magY: mag?.y,
      magZ: mag?.z,
    );
  }

  IMUSensorData copyWith({
    DateTime? timestamp,
    double? accelX,
    double? accelY,
    double? accelZ,
    double? gyroX,
    double? gyroY,
    double? gyroZ,
    double? magX,
    double? magY,
    double? magZ,
  }) {
    return IMUSensorData(
      timestamp: timestamp ?? this.timestamp,
      accelX: accelX ?? this.accelX,
      accelY: accelY ?? this.accelY,
      accelZ: accelZ ?? this.accelZ,
      gyroX: gyroX ?? this.gyroX,
      gyroY: gyroY ?? this.gyroY,
      gyroZ: gyroZ ?? this.gyroZ,
      magX: magX ?? this.magX,
      magY: magY ?? this.magY,
      magZ: magZ ?? this.magZ,
    );
  }
}

/// 设备方向
enum IMUDeviceOrientation {
  portraitUp,
  portraitDown,
  landscapeLeft,
  landscapeRight,
  faceUp,
  faceDown,
  unknown,
}

/// 动作类型
enum MotionType {
  stationary,      // 静止
  moving,          // 移动 (低强度)
  walking,         // 行走
  running,         // 跑步
  shake,           // 摇晃
  vigorousShake,   // 剧烈摇晃
  freeFall,        // 自由落体
  possibleFall,    // 可能跌倒
  fall,            // 跌倒
  unknown,         // 未知
}

/// 动作事件
class MotionEvent {
  final MotionType type;
  final DateTime timestamp;
  final double confidence;
  final Map<String, dynamic>? data;

  MotionEvent({
    required this.type,
    required this.timestamp,
    this.confidence = 0.0,
    this.data,
  });
}

/// IMU传感器服务
/// 管理手机内置传感器的访问和数据流
class IMUSensorService {
  static const String _tag = 'IMUSensorService';
  
  // 数据流控制器
  final StreamController<IMUSensorData> _dataController = 
      StreamController<IMUSensorData>.broadcast();
  final StreamController<MotionEvent> _motionController = 
      StreamController<MotionEvent>.broadcast();
  final StreamController<IMUDeviceOrientation> _orientationController = 
      StreamController<IMUDeviceOrientation>.broadcast();

  // 订阅
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<MagnetometerEvent>? _magSubscription;

  // 当前传感器数据
  AccelerometerEvent? _lastAccel;
  GyroscopeEvent? _lastGyro;
  MagnetometerEvent? _lastMag;

  // 采样配置
  static const Duration _samplingInterval = Duration(milliseconds: 20); // 50Hz
  Timer? _dataTimer;

  /// 是否在运行
  bool _isRunning = false;
  Stream<IMUSensorData> get dataStream => _dataController.stream;
  Stream<MotionEvent> get motionStream => _motionController.stream;
  Stream<IMUDeviceOrientation> get orientationStream => _orientationController.stream;
  bool get isRunning => _isRunning;

  /// 启动传感器服务
  Future<void> start() async {
    if (_isRunning) return;

    AppLogger.info('[$_tag] Starting IMU sensor service...');

    try {
      // 订阅加速度计
      _accelSubscription = sensors.accelerometerEventStream()
          .listen(_onAccelEvent, onError: _onSensorError);

      // 订阅陀螺仪
      _gyroSubscription = gyroscopeEventStream()
          .listen(_onGyroEvent, onError: _onSensorError);

      // 订阅磁力计（可选）
      _magSubscription = magnetometerEventStream()
          .listen(_onMagEvent, onError: _onSensorError);

      // 启动数据融合定时器
      _dataTimer = Timer.periodic(_samplingInterval, (_) => _processSensorData());

      _isRunning = true;
      AppLogger.info('[$_tag] IMU sensor service started');
    } catch (e) {
      AppLogger.error('[$_tag] Failed to start IMU sensor service', e);
      rethrow;
    }
  }

  /// 停止传感器服务
  Future<void> stop() async {
    if (!_isRunning) return;

    AppLogger.info('[$_tag] Stopping IMU sensor service...');

    _dataTimer?.cancel();
    _dataTimer = null;

    await _accelSubscription?.cancel();
    await _gyroSubscription?.cancel();
    await _magSubscription?.cancel();

    _accelSubscription = null;
    _gyroSubscription = null;
    _magSubscription = null;

    _isRunning = false;
    AppLogger.info('[$_tag] IMU sensor service stopped');
  }

  /// 加速度计事件处理
  void _onAccelEvent(AccelerometerEvent event) {
    _lastAccel = event;
    _detectOrientation(event);
  }

  /// 陀螺仪事件处理
  void _onGyroEvent(GyroscopeEvent event) {
    _lastGyro = event;
  }

  /// 磁力计事件处理
  void _onMagEvent(MagnetometerEvent event) {
    _lastMag = event;
  }

  /// 传感器错误处理
  void _onSensorError(Object error) {
    AppLogger.error('[$_tag] Sensor error', error);
  }

  /// 处理传感器数据融合
  void _processSensorData() {
    if (_lastAccel == null || _lastGyro == null) return;

    final data = IMUSensorData.fromSensors(
      accel: _lastAccel!,
      gyro: _lastGyro!,
      mag: _lastMag,
    );

    _dataController.add(data);
    _detectMotion(data);
  }

  /// 检测设备方向
  void _detectOrientation(AccelerometerEvent accel) {
    // 使用原始加速度计数据（包含重力）来检测方向
    
    IMUDeviceOrientation orientation;
    
    if (accel.z.abs() > accel.x.abs() && accel.z.abs() > accel.y.abs()) {
      // Z轴主导
      orientation = accel.z > 0 ? IMUDeviceOrientation.faceUp : IMUDeviceOrientation.faceDown;
    } else if (accel.y.abs() > accel.x.abs()) {
      // Y轴主导
      orientation = accel.y > 0 ? IMUDeviceOrientation.portraitUp : IMUDeviceOrientation.portraitDown;
    } else {
      // X轴主导
      orientation = accel.x > 0 ? IMUDeviceOrientation.landscapeRight : IMUDeviceOrientation.landscapeLeft;
    }
    
    _orientationController.add(orientation);
  }

  // 运动检测状态
  final List<double> _accelHistory = [];
  static const int _historySize = 25; // 0.5秒的历史数据 (50Hz * 0.5s)
  MotionType _lastMotionType = MotionType.unknown;
  DateTime? _lastMotionTime;

  /// 运动检测算法
  void _detectMotion(IMUSensorData data) {
    final magnitude = data.accelMagnitude;
    
    // 更新历史数据
    _accelHistory.add(magnitude);
    if (_accelHistory.length > _historySize) {
      _accelHistory.removeAt(0);
    }

    if (_accelHistory.length < _historySize) return;

    // 计算统计特征
    final mean = _accelHistory.reduce((a, b) => a + b) / _accelHistory.length;
    final variance = _accelHistory
        .map((v) => (v - mean) * (v - mean))
        .reduce((a, b) => a + b) / _accelHistory.length;
    final stdDev = math.sqrt(variance);
    final maxAccel = _accelHistory.reduce(math.max);

    // 跌倒检测算法
    MotionType currentMotion = MotionType.unknown;
    double confidence = 0.0;

    // 1. 自由落体检测 - 加速度接近0
    if (mean < 2.5 && stdDev < 1.2) {
      currentMotion = MotionType.freeFall;
      confidence = 0.95;
    }
    // 2. 跌倒检测 - 剧烈加速度变化后静止
    // 优化：增加更严格的冲击阈值和静止窗口判断
    else if (maxAccel > 28.0 && stdDev > 9.0) {
      // 检查是否在冲击后由动态转为极度静止（典型跌倒特征）
      final secondHalf = _accelHistory.skip(_historySize ~/ 2).toList();
      final recentMean = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
      final recentStd = math.sqrt(secondHalf.map((v) => (v - recentMean) * (v - recentMean)).reduce((a, b) => a + b) / secondHalf.length);
      
      if (recentMean < 11.0 && recentStd < 2.0) {
        currentMotion = MotionType.fall; // 升级为确认跌倒
        confidence = 0.85;
      } else {
        currentMotion = MotionType.possibleFall;
        confidence = 0.6;
      }
    }
    // 3. 跑步运行检测 - 高方差且周期性
    else if (stdDev > 5.5 && mean > 14.0) {
      currentMotion = MotionType.running;
      confidence = 0.85;
    }
    // 4. 行走检测 - 中等方差
    else if (stdDev > 1.8 && stdDev <= 5.5 && mean > 9.5) {
      currentMotion = MotionType.walking;
      confidence = 0.8;
    }
    // 5. 移动检测 (Moving) - 低于行走的轻微位移
    else if (stdDev > 0.8 && stdDev <= 1.8) {
      currentMotion = MotionType.moving;
      confidence = 0.7;
    }
    // 6. 剧烈摇晃 (Vigorous Shake)
    else if (stdDev > 18.0) {
      currentMotion = MotionType.vigorousShake;
      confidence = 0.95;
    }
    // 7. 普通摇晃检测
    else if (stdDev > 10.0) {
      currentMotion = MotionType.shake;
      confidence = 0.9;
    }
    // 8. 静止检测
    else if (stdDev < 0.8 && mean > 9.0 && mean < 11.0) {
      currentMotion = MotionType.stationary;
      confidence = 0.95;
    }

    // 防抖：只有当运动类型持续一段时间才报告
    final now = DateTime.now();
    if (currentMotion != _lastMotionType) {
      if (_lastMotionTime != null) {
        final duration = now.difference(_lastMotionTime!);
        if (duration.inMilliseconds > 200) { // 200ms防抖
          _lastMotionType = currentMotion;
          _lastMotionTime = now;
          _motionController.add(MotionEvent(
            type: currentMotion,
            timestamp: now,
            confidence: confidence,
            data: {
              'meanAccel': mean,
              'stdDev': stdDev,
              'maxAccel': maxAccel,
            },
          ));
        }
      } else {
        _lastMotionTime = now;
      }
    } else {
      _lastMotionTime = now;
    }
  }

  /// 重置运动检测状态
  void resetMotionDetection() {
    _accelHistory.clear();
    _lastMotionType = MotionType.unknown;
    _lastMotionTime = null;
  }

  void dispose() {
    stop();
    _dataController.close();
    _motionController.close();
    _orientationController.close();
  }
}
