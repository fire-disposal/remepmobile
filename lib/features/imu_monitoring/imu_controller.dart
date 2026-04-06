import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/utils/logger.dart';
import 'imu_sensor_service.dart';

/// IMU数据历史记录
class IMUDataHistory {
  final List<IMUSensorData> _data = [];
  final int maxSize;

  IMUDataHistory({this.maxSize = 500}); // 10秒 @ 50Hz

  List<IMUSensorData> get data => List.unmodifiable(_data);
  int get length => _data.length;
  bool get isEmpty => _data.isEmpty;
  bool get isNotEmpty => _data.isNotEmpty;

  void add(IMUSensorData value) {
    _data.add(value);
    if (_data.length > maxSize) {
      _data.removeAt(0);
    }
  }

  void clear() {
    _data.clear();
  }

  /// 获取最近N个数据点
  List<IMUSensorData> getRecent(int count) {
    if (_data.length <= count) return List.unmodifiable(_data);
    return List.unmodifiable(_data.sublist(_data.length - count));
  }

  /// 获取最近一段时间的数据
  List<IMUSensorData> getRecentDuration(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return List.unmodifiable(_data.where((d) => d.timestamp.isAfter(cutoff)));
  }

  /// 计算统计信息
  Map<String, double> getStatistics() {
    if (_data.isEmpty) return {};

    final accels = _data.map((d) => d.accelMagnitude).toList();
    final gyros = _data.map((d) => d.gyroMagnitude).toList();

    double mean(List<double> values) => 
        values.reduce((a, b) => a + b) / values.length;
    
    double stdDev(List<double> values, double mean) {
      final variance = values.map((v) => (v - mean) * (v - mean))
          .reduce((a, b) => a + b) / values.length;
      return math.sqrt(variance);
    }

    final accelMean = mean(accels);
    final gyroMean = mean(gyros);

    return {
      'accelMean': accelMean,
      'accelStd': stdDev(accels, accelMean),
      'accelMax': accels.reduce(math.max),
      'accelMin': accels.reduce(math.min),
      'gyroMean': gyroMean,
      'gyroStd': stdDev(gyros, gyroMean),
      'gyroMax': gyros.reduce(math.max),
      'gyroMin': gyros.reduce(math.min),
    };
  }
}

/// IMU控制器状态
class IMUControllerState {
  final bool isRunning;
  final bool hasPermission;
  final IMUSensorData? latestData;
  final MotionType currentMotion;
  final IMUDeviceOrientation orientation;
  final double motionConfidence;
  final List<MotionEvent> motionEvents;
  final Map<String, double> statistics;

  const IMUControllerState({
    this.isRunning = false,
    this.hasPermission = false,
    this.latestData,
    this.currentMotion = MotionType.unknown,
    this.orientation = IMUDeviceOrientation.unknown,
    this.motionConfidence = 0.0,
    this.motionEvents = const [],
    this.statistics = const {},
  });

  IMUControllerState copyWith({
    bool? isRunning,
    bool? hasPermission,
    IMUSensorData? latestData,
    MotionType? currentMotion,
    IMUDeviceOrientation? orientation,
    double? motionConfidence,
    List<MotionEvent>? motionEvents,
    Map<String, double>? statistics,
  }) {
    return IMUControllerState(
      isRunning: isRunning ?? this.isRunning,
      hasPermission: hasPermission ?? this.hasPermission,
      latestData: latestData ?? this.latestData,
      currentMotion: currentMotion ?? this.currentMotion,
      orientation: orientation ?? this.orientation,
      motionConfidence: motionConfidence ?? this.motionConfidence,
      motionEvents: motionEvents ?? this.motionEvents,
      statistics: statistics ?? this.statistics,
    );
  }
}

/// IMU控制器
class IMUController extends ChangeNotifier {
  final IMUSensorService _sensorService;
  static const String _tag = 'IMUController';

  // 状态
  IMUControllerState _state = const IMUControllerState();
  IMUControllerState get state => _state;

  // 数据历史
  final IMUDataHistory _dataHistory = IMUDataHistory();
  IMUDataHistory get dataHistory => _dataHistory;

  // 运动事件历史（限制大小）
  final Queue<MotionEvent> _motionEvents = Queue<MotionEvent>();
  static const int _maxMotionEvents = 50;

  // 订阅
  StreamSubscription<IMUSensorData>? _dataSubscription;
  StreamSubscription<MotionEvent>? _motionSubscription;
  StreamSubscription<IMUDeviceOrientation>? _orientationSubscription;

  // 定时器
  Timer? _statsTimer;

  IMUController({IMUSensorService? sensorService})
      : _sensorService = sensorService ?? IMUSensorService();

  /// 初始化并启动
  Future<void> initialize() async {
    AppLogger.info('[$_tag] Initializing IMU controller...');
    
    _state = _state.copyWith(hasPermission: true);
    notifyListeners();

    // 订阅数据流
    _dataSubscription = _sensorService.dataStream.listen(_onDataReceived);
    _motionSubscription = _sensorService.motionStream.listen(_onMotionDetected);
    _orientationSubscription = _sensorService.orientationStream.listen(_onOrientationChanged);

    // 启动统计更新定时器
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateStatistics());

    await start();
  }

  /// 启动传感器
  Future<void> start() async {
    try {
      await _sensorService.start();
      _state = _state.copyWith(isRunning: true);
      notifyListeners();
      AppLogger.info('[$_tag] IMU controller started');
    } catch (e) {
      AppLogger.error('[$_tag] Failed to start IMU controller', e);
      _state = _state.copyWith(isRunning: false);
      notifyListeners();
    }
  }

  /// 停止传感器
  Future<void> stop() async {
    await _sensorService.stop();
    _state = _state.copyWith(isRunning: false);
    notifyListeners();
    AppLogger.info('[$_tag] IMU controller stopped');
  }

  /// 数据接收处理
  void _onDataReceived(IMUSensorData data) {
    _dataHistory.add(data);
    _state = _state.copyWith(latestData: data);
    notifyListeners();
  }

  /// 运动检测处理
  void _onMotionDetected(MotionEvent event) {
    _motionEvents.addFirst(event);
    while (_motionEvents.length > _maxMotionEvents) {
      _motionEvents.removeLast();
    }

    _state = _state.copyWith(
      currentMotion: event.type,
      motionConfidence: event.confidence,
      motionEvents: List.unmodifiable(_motionEvents.toList()),
    );
    notifyListeners();

    AppLogger.info('[$_tag] Motion detected: ${event.type} (confidence: ${event.confidence.toStringAsFixed(2)})');
  }

  /// 方向变化处理
  void _onOrientationChanged(IMUDeviceOrientation orientation) {
    _state = _state.copyWith(orientation: orientation);
    notifyListeners();
  }

  /// 更新统计信息
  void _updateStatistics() {
    final stats = _dataHistory.getStatistics();
    _state = _state.copyWith(statistics: stats);
    notifyListeners();
  }

  /// 清除历史数据
  void clearHistory() {
    _dataHistory.clear();
    _motionEvents.clear();
    _sensorService.resetMotionDetection();
    _state = _state.copyWith(
      currentMotion: MotionType.unknown,
      motionConfidence: 0.0,
      motionEvents: const [],
      statistics: const {},
    );
    notifyListeners();
  }

  /// 获取最近的运动事件
  List<MotionEvent> getRecentMotionEvents({int count = 10}) {
    return _motionEvents.take(count).toList();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _dataSubscription?.cancel();
    _motionSubscription?.cancel();
    _orientationSubscription?.cancel();
    _sensorService.dispose();
    super.dispose();
  }
}

/// 动作行为检测器
/// 提供更复杂的动作识别算法
class MotionBehaviorDetector {
  /// 检测跌倒
  static FallDetectionResult detectFall(List<IMUSensorData> data) {
    if (data.length < 50) {
      return FallDetectionResult(
        isFall: false,
        confidence: 0.0,
        reason: '数据不足',
      );
    }

    // 跌倒检测特征
    // 1. 冲击阶段：高加速度峰值 (>25 m/s²)
    // 2. 静止阶段：冲击后低加速度方差
    // 3. 姿态变化：从竖直到水平

    final recentData = data.sublist(data.length - 50);
    final accelMagnitudes = recentData.map((d) => d.accelMagnitude).toList();
    
    // 查找冲击峰值
    double maxAccel = 0;
    int impactIndex = -1;
    for (int i = 0; i < accelMagnitudes.length; i++) {
      if (accelMagnitudes[i] > maxAccel) {
        maxAccel = accelMagnitudes[i];
        impactIndex = i;
      }
    }

    // 没有足够大的冲击
    if (maxAccel < 20.0) {
      return FallDetectionResult(
        isFall: false,
        confidence: 0.0,
        reason: '未检测到足够大的冲击',
      );
    }

    // 检查冲击后是否有静止
    if (impactIndex >= 0 && impactIndex < accelMagnitudes.length - 10) {
      final postImpact = accelMagnitudes.sublist(impactIndex + 1);
      final meanPostImpact = postImpact.reduce((a, b) => a + b) / postImpact.length;
      
      if (meanPostImpact < 12.0) {
        // 计算置信度
        double confidence = (maxAccel - 20.0) / 30.0; // 20-50 m/s² 映射到 0-1
        confidence = confidence.clamp(0.5, 0.95);
        
        return FallDetectionResult(
          isFall: true,
          confidence: confidence,
          impactForce: maxAccel,
          reason: '检测到冲击后静止',
        );
      }
    }

    return FallDetectionResult(
      isFall: false,
      confidence: 0.3,
      impactForce: maxAccel,
      reason: '冲击后未检测到静止状态',
    );
  }

  /// 计算步数
  static StepCountResult countSteps(List<IMUSensorData> data) {
    if (data.length < 25) {
      return StepCountResult(count: 0, cadence: 0.0);
    }

    // 使用Z轴加速度检测步态
    // 寻找峰值
    int steps = 0;
    final zAccels = data.map((d) => d.accelZ).toList();
    
    // 简单峰值检测
    for (int i = 2; i < zAccels.length - 2; i++) {
      if (zAccels[i] > zAccels[i-1] && 
          zAccels[i] > zAccels[i-2] &&
          zAccels[i] > zAccels[i+1] && 
          zAccels[i] > zAccels[i+2] &&
          zAccels[i] > 2.0) {
        steps++;
      }
    }

    // 计算步频 (步/分钟)
    final duration = data.last.timestamp.difference(data.first.timestamp);
    final minutes = duration.inSeconds / 60.0;
    final cadence = minutes > 0 ? steps / minutes : 0.0;

    return StepCountResult(count: steps, cadence: cadence);
  }

  /// 分析活动强度
  static ActivityIntensity analyzeIntensity(List<IMUSensorData> data) {
    if (data.isEmpty) return ActivityIntensity.unknown;

    final meanAccel = data.map((d) => d.accelMagnitude).reduce((a, b) => a + b) / data.length;
    final meanGyro = data.map((d) => d.gyroMagnitude).reduce((a, b) => a + b) / data.length;

    // 基于加速度和陀螺仪的活动强度分类
    if (meanAccel < 1.5 && meanGyro < 0.5) {
      return ActivityIntensity.sedentary;
    } else if (meanAccel < 5.0 && meanGyro < 1.0) {
      return ActivityIntensity.light;
    } else if (meanAccel < 15.0 && meanGyro < 3.0) {
      return ActivityIntensity.moderate;
    } else {
      return ActivityIntensity.vigorous;
    }
  }
}

/// 跌倒检测结果
class FallDetectionResult {
  final bool isFall;
  final double confidence;
  final double? impactForce;
  final String reason;

  FallDetectionResult({
    required this.isFall,
    required this.confidence,
    this.impactForce,
    required this.reason,
  });
}

/// 步数结果
class StepCountResult {
  final int count;
  final double cadence; // 步/分钟

  StepCountResult({required this.count, required this.cadence});
}

/// 活动强度
enum ActivityIntensity {
  unknown,
  sedentary,    // 久坐
  light,        // 轻度
  moderate,     // 中度
  vigorous,     // 剧烈
}
