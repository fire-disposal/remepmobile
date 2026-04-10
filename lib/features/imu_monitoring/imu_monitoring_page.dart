import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/events/global_event_store.dart';
import '../../core/mqtt/mqtt_config_service.dart';
import '../../core/permission/permission_service.dart';
import '../../core/theme/design_language.dart';
import 'imu_controller.dart';
import 'imu_sensor_service.dart';
import 'widgets/sensor_data_card.dart';

/// IMU监测页面 - 直接使用内置传感器
class ImuMonitoringPage extends StatefulWidget {
  const ImuMonitoringPage({super.key});

  @override
  State<ImuMonitoringPage> createState() => _ImuMonitoringPageState();
}

class _ImuMonitoringPageState extends State<ImuMonitoringPage>
    with WidgetsBindingObserver {
  late final IMUController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final permissionService = getIt<PermissionService>();
    
    // 直接请求所需权限
    await permissionService.requestIMUPermissions();
    
    _controller = IMUController(
      sensorService: getIt<IMUSensorService>(),
      mqttConfigService: getIt<MqttConfigService>(),
      eventStore: getIt<GlobalEventStore>(),
    );
    await _controller.initialize();
    
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'IMU 运动监测',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
        ),
        actions: [
          IconButton(
            onPressed: () => _controller.clearHistory(),
            icon: const Icon(Icons.clear_all),
            tooltip: '清除',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isInitialized 
        ? _buildMonitoringView()
        : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildMonitoringView() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final state = _controller.state;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 状态栏
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDesignLanguage.pageHorizontalPadding, vertical: 8),
                child: _buildStatusBar(state),
              ),
            ),

            // 运动状态卡片
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDesignLanguage.pageHorizontalPadding),
                child: MotionStatusCard(
                  motionType: state.currentMotion,
                  confidence: state.motionConfidence,
                  recentEvents: state.motionEvents.take(5).toList(),
                ),
              ),
            ),

            // 数据可视化
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDesignLanguage.pageHorizontalPadding),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 900) {
                      return Column(
                        children: [
                          SensorDataCard(
                            data: _controller.dataHistory.data,
                            isCompact: true,
                          ),
                          const SizedBox(height: 12),
                          OrientationSphereCard(
                            data: state.latestData,
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: SensorDataCard(
                            data: _controller.dataHistory.data,
                            isCompact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: OrientationSphereCard(
                            data: state.latestData,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // 统计数据
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDesignLanguage.pageHorizontalPadding),
                child: _buildStatisticsCard(state.statistics),
              ),
            ),

            // 原始数据
            if (state.latestData != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDesignLanguage.pageHorizontalPadding),
                  child: _buildRawDataCard(state.latestData!),
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        );
      },
    );
  }

  Widget _buildStatusBar(IMUControllerState state) {
    final isAlert = state.currentMotion == MotionType.fall || 
                    state.currentMotion == MotionType.freeFall;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isAlert 
          ? Colors.red.withValues(alpha: 0.15)
          : (state.isRunning
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1)),
        borderRadius: AppDesignLanguage.panelRadius,
        border: Border.all(
          color: isAlert
            ? Colors.red.withValues(alpha: 0.5)
            : (state.isRunning
                ? Colors.green.withValues(alpha: 0.3)
                : Colors.orange.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isAlert ? Colors.red : (state.isRunning ? Colors.green : Colors.orange),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isAlert ? '⚠ 警报' : (state.isRunning ? '监测中' : '已暂停'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isAlert ? Colors.red : (state.isRunning ? Colors.green : Colors.orange),
            ),
          ),
          const Spacer(),
          Text(
            '${_getOrientationText(state.orientation)} · 50Hz',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _getOrientationText(IMUDeviceOrientation orientation) {
    switch (orientation) {
      case IMUDeviceOrientation.portraitUp: return '竖屏';
      case IMUDeviceOrientation.portraitDown: return '倒竖屏';
      case IMUDeviceOrientation.landscapeLeft: return '左横屏';
      case IMUDeviceOrientation.landscapeRight: return '右横屏';
      case IMUDeviceOrientation.faceUp: return '面朝上';
      case IMUDeviceOrientation.faceDown: return '面朝下';
      case IMUDeviceOrientation.unknown: return '未知';
    }
  }

  Widget _buildStatisticsCard(Map<String, double> statistics) {
    if (statistics.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: AppDesignLanguage.panelRadius,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: '加速度均值',
            value: '${statistics['accelMean']?.toStringAsFixed(2) ?? '--'}',
            unit: 'm/s²',
            color: Colors.blue,
          ),
          _StatItem(
            label: '方差',
            value: '${statistics['accelStd']?.toStringAsFixed(2) ?? '--'}',
            unit: '',
            color: Colors.orange,
          ),
          _StatItem(
            label: '最大值',
            value: '${statistics['accelMax']?.toStringAsFixed(2) ?? '--'}',
            unit: 'm/s²',
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildRawDataCard(IMUSensorData data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: AppDesignLanguage.panelRadius,
        border: Border.all(color: Colors.grey.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '传感器数据',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 460;
              final children = [
                _DataRow(
                  label: 'Accel',
                  x: data.accelX,
                  y: data.accelY,
                  z: data.accelZ,
                  unit: 'm/s²',
                ),
                _DataRow(
                  label: 'Gyro',
                  x: data.gyroX,
                  y: data.gyroY,
                  z: data.gyroZ,
                  unit: 'rad/s',
                ),
              ];

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    children[0],
                    const SizedBox(height: 8),
                    children[1],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 16),
                  Expanded(child: children[1]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final double x, y, z;
  final String unit;

  const _DataRow({required this.label, required this.x, required this.y, required this.z, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 4),
        _ValueText('X', x, Colors.red),
        _ValueText('Y', y, Colors.green),
        _ValueText('Z', z, Colors.blue),
      ],
    );
  }

  Widget _ValueText(String axis, double value, Color color) {
    return Text(
      '$axis: ${value.toStringAsFixed(2)} $unit',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, color: color, fontFamily: 'monospace'),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
        ),
        if (unit.isNotEmpty)
          Text(
            unit,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
