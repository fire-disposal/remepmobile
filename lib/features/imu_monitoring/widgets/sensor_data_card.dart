import 'package:flutter/material.dart';

import '../imu_sensor_service.dart';
import 'imu_waveform_painter.dart';

/// 传感器数据卡片
class SensorDataCard extends StatelessWidget {
  final List<IMUSensorData> data;
  final bool isCompact;

  const SensorDataCard({
    super.key,
    required this.data,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '实时波形',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildLegend(),
            ],
          ),
          const SizedBox(height: 12),
          if (isCompact) ...[
            _buildCompactWaveforms(),
          ] else ...[
            _buildFullWaveforms(),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendItem(color: Colors.red, label: 'X'),
        _LegendItem(color: Colors.green, label: 'Y'),
        _LegendItem(color: Colors.blue, label: 'Z'),
      ],
    );
  }

  Widget _buildCompactWaveforms() {
    return Column(
      children: [
        _WaveformRow(
          label: '加速度',
          unit: 'm/s²',
          data: data,
          types: const [WaveformType.accelX, WaveformType.accelY, WaveformType.accelZ],
          colors: const [Colors.red, Colors.green, Colors.blue],
          height: 60,
        ),
        const SizedBox(height: 12),
        _WaveformRow(
          label: '陀螺仪',
          unit: 'rad/s',
          data: data,
          types: const [WaveformType.gyroX, WaveformType.gyroY, WaveformType.gyroZ],
          colors: const [Colors.red, Colors.green, Colors.blue],
          height: 60,
        ),
      ],
    );
  }

  Widget _buildFullWaveforms() {
    return Column(
      children: [
        _buildWaveformSection(
          '加速度 X轴',
          WaveformType.accelX,
          Colors.red,
        ),
        const SizedBox(height: 8),
        _buildWaveformSection(
          '加速度 Y轴',
          WaveformType.accelY,
          Colors.green,
        ),
        const SizedBox(height: 8),
        _buildWaveformSection(
          '加速度 Z轴',
          WaveformType.accelZ,
          Colors.blue,
        ),
        const Divider(height: 24),
        _buildWaveformSection(
          '陀螺仪 X轴',
          WaveformType.gyroX,
          Colors.red,
        ),
        const SizedBox(height: 8),
        _buildWaveformSection(
          '陀螺仪 Y轴',
          WaveformType.gyroY,
          Colors.green,
        ),
        const SizedBox(height: 8),
        _buildWaveformSection(
          '陀螺仪 Z轴',
          WaveformType.gyroZ,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildWaveformSection(String label, WaveformType type, Color color) {
    final recentData = data.length > 100 ? data.sublist(data.length - 100) : data;
    
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 50,
            child: CustomPaint(
              size: Size.infinite,
              painter: IMUWaveformPainter(
                data: recentData,
                type: type,
                color: color,
                fillColor: color.withValues(alpha: 0.1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 波形行组件
class _WaveformRow extends StatelessWidget {
  final String label;
  final String unit;
  final List<IMUSensorData> data;
  final List<WaveformType> types;
  final List<Color> colors;
  final double height;

  const _WaveformRow({
    required this.label,
    required this.unit,
    required this.data,
    required this.types,
    required this.colors,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final recentData = data.length > 100 ? data.sublist(data.length - 100) : data;
    
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SizedBox(
            height: height,
            child: Stack(
              children: List.generate(types.length, (index) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: IMUWaveformPainter(
                    data: recentData,
                    type: types[index],
                    color: colors[index],
                    showGrid: index == 0,
                    showValue: index == 0,
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

/// 图例项
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// 方向球卡片
class OrientationSphereCard extends StatelessWidget {
  final IMUSensorData? data;

  const OrientationSphereCard({
    super.key,
    this.data,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.threed_rotation,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '3D方向',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.2,
            child: CustomPaint(
              size: Size.infinite,
              painter: OrientationSpherePainter(
                data: data,
                primaryColor: theme.colorScheme.primary,
                secondaryColor: theme.colorScheme.secondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _buildOrientationInfo(),
        ],
      ),
    );
  }

  Widget _buildOrientationInfo() {
    if (data == null) {
      return const Center(
        child: Text('等待数据...', style: TextStyle(color: Colors.grey)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _OrientationInfoItem(
          label: 'Pitch',
          value: '${(data!.pitch * 180 / 3.14159).toStringAsFixed(1)}°',
          color: Colors.green,
        ),
        _OrientationInfoItem(
          label: 'Roll',
          value: '${(data!.roll * 180 / 3.14159).toStringAsFixed(1)}°',
          color: Colors.red,
        ),
      ],
    );
  }
}

class _OrientationInfoItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _OrientationInfoItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// 运动状态卡片
class MotionStatusCard extends StatelessWidget {
  final MotionType motionType;
  final double confidence;
  final List<MotionEvent> recentEvents;

  const MotionStatusCard({
    super.key,
    required this.motionType,
    required this.confidence,
    required this.recentEvents,
  });

  Color get _statusColor {
    switch (motionType) {
      case MotionType.stationary:
        return Colors.grey;
      case MotionType.walking:
        return Colors.green;
      case MotionType.running:
        return Colors.blue;
      case MotionType.shake:
        return Colors.orange;
      case MotionType.freeFall:
        return Colors.purple;
      case MotionType.possibleFall:
        return Colors.amber;
      case MotionType.fall:
        return Colors.red;
      case MotionType.unknown:
        return Colors.grey.withValues(alpha: 0.5);
    }
  }

  String get _statusText {
    switch (motionType) {
      case MotionType.stationary:
        return '静止';
      case MotionType.walking:
        return '行走中';
      case MotionType.running:
        return '跑步中';
      case MotionType.shake:
        return '检测到摇晃';
      case MotionType.freeFall:
        return '自由落体！';
      case MotionType.possibleFall:
        return '可能跌倒';
      case MotionType.fall:
        return '跌倒警报！';
      case MotionType.unknown:
        return '检测中...';
    }
  }

  IconData get _statusIcon {
    switch (motionType) {
      case MotionType.stationary:
        return Icons.pause_circle;
      case MotionType.walking:
        return Icons.directions_walk;
      case MotionType.running:
        return Icons.directions_run;
      case MotionType.shake:
        return Icons.vibration;
      case MotionType.freeFall:
        return Icons.arrow_downward;
      case MotionType.possibleFall:
      case MotionType.fall:
        return Icons.warning_rounded;
      case MotionType.unknown:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAlert = motionType == MotionType.fall || motionType == MotionType.freeFall;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAlert ? Colors.red.shade50 : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlert ? Colors.red.withValues(alpha: 0.35) : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sensors,
                color: isAlert ? Colors.red : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '运动检测',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isAlert) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '警报',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;
              final indicator = SizedBox(
                width: isNarrow ? 90 : 120,
                height: isNarrow ? 90 : 120,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: MotionIndicatorPainter(
                    motionType: motionType,
                    confidence: confidence,
                  ),
                ),
              );

              final detail = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon, color: _statusColor, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _statusText,
                          style: TextStyle(
                            color: _statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildRecentEvents(),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    indicator,
                    const SizedBox(height: 8),
                    detail,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  indicator,
                  const SizedBox(width: 12),
                  Expanded(child: detail),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEvents() {
    if (recentEvents.isEmpty) {
      return const Text(
        '暂无事件记录',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: recentEvents.take(3).map((event) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _getEventColor(event.type),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getEventName(event.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              Text(
                _formatTime(event.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getEventColor(MotionType type) {
    switch (type) {
      case MotionType.fall:
      case MotionType.freeFall:
        return Colors.red;
      case MotionType.possibleFall:
        return Colors.orange;
      case MotionType.running:
        return Colors.blue;
      case MotionType.walking:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getEventName(MotionType type) {
    switch (type) {
      case MotionType.stationary:
        return '静止';
      case MotionType.walking:
        return '行走';
      case MotionType.running:
        return '跑步';
      case MotionType.shake:
        return '摇晃';
      case MotionType.freeFall:
        return '自由落体';
      case MotionType.possibleFall:
        return '可能跌倒';
      case MotionType.fall:
        return '跌倒';
      case MotionType.unknown:
        return '未知';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
