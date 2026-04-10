import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../imu_sensor_service.dart';

/// 波形图类型
enum WaveformType {
  accelX,
  accelY,
  accelZ,
  accelMagnitude,
  gyroX,
  gyroY,
  gyroZ,
  gyroMagnitude,
}

/// 波形图绘制器
class IMUWaveformPainter extends CustomPainter {
  final List<IMUSensorData> data;
  final WaveformType type;
  final Color color;
  final Color? fillColor;
  final double lineWidth;
  final bool showGrid;
  final bool showValue;

  IMUWaveformPainter({
    required this.data,
    required this.type,
    required this.color,
    this.fillColor,
    this.lineWidth = 2.0,
    this.showGrid = true,
    this.showValue = true,
  });

  double _getValue(IMUSensorData d) {
    switch (type) {
      case WaveformType.accelX:
        return d.accelX;
      case WaveformType.accelY:
        return d.accelY;
      case WaveformType.accelZ:
        return d.accelZ;
      case WaveformType.accelMagnitude:
        return d.accelMagnitude;
      case WaveformType.gyroX:
        return d.gyroX;
      case WaveformType.gyroY:
        return d.gyroY;
      case WaveformType.gyroZ:
        return d.gyroZ;
      case WaveformType.gyroMagnitude:
        return d.gyroMagnitude;
    }
  }

  double _getMinValue() {
    switch (type) {
      case WaveformType.accelX:
      case WaveformType.accelY:
      case WaveformType.accelZ:
        return -20;
      case WaveformType.accelMagnitude:
        return 0;
      case WaveformType.gyroX:
      case WaveformType.gyroY:
      case WaveformType.gyroZ:
        return -10;
      case WaveformType.gyroMagnitude:
        return 0;
    }
  }

  double _getMaxValue() {
    switch (type) {
      case WaveformType.accelX:
      case WaveformType.accelY:
      case WaveformType.accelZ:
        return 20;
      case WaveformType.accelMagnitude:
        return 25;
      case WaveformType.gyroX:
      case WaveformType.gyroY:
      case WaveformType.gyroZ:
        return 10;
      case WaveformType.gyroMagnitude:
        return 15;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final minValue = _getMinValue();
    final maxValue = _getMaxValue();
    final valueRange = maxValue - minValue;

    // 绘制网格
    if (showGrid) {
      _drawGrid(canvas, size, minValue, maxValue);
    }

    // 绘制波形
    final paint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = fillColor != null
        ? (Paint()
          ..color = fillColor!
          ..style = PaintingStyle.fill)
        : null;

    final path = Path();
    final fillPath = fillColor != null ? Path() : null;

    final width = size.width;
    final height = size.height;
    final dx = width / (data.length - 1);

    // 移动到第一个点
    final firstValue = _getValue(data.first);
    final firstY = height - ((firstValue - minValue) / valueRange) * height;
    path.moveTo(0, firstY);
    fillPath?.moveTo(0, height);
    fillPath?.lineTo(0, firstY);

    // 绘制线条
    for (int i = 1; i < data.length; i++) {
      final value = _getValue(data[i]);
      final x = i * dx;
      final y = height - ((value - minValue) / valueRange) * height;
      
      // 使用贝塞尔曲线平滑连接
      final prevX = (i - 1) * dx;
      final prevValue = _getValue(data[i - 1]);
      final prevY = height - ((prevValue - minValue) / valueRange) * height;
      
      final cpX1 = prevX + dx * 0.5;
      final cpY1 = prevY;
      final cpX2 = x - dx * 0.5;
      final cpY2 = y;
      
      path.cubicTo(cpX1, cpY1, cpX2, cpY2, x, y);
      fillPath?.lineTo(x, y);
    }

    fillPath?.lineTo(width, height);
    fillPath?.close();

    if (fillPaint != null && fillPath != null) {
      canvas.drawPath(fillPath, fillPaint);
    }
    canvas.drawPath(path, paint);

    // 绘制中心线
    final centerPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    final centerY = height - ((0 - minValue) / valueRange) * height;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(width, centerY),
      centerPaint,
    );

    // 绘制当前值
    if (showValue && data.isNotEmpty) {
      final currentValue = _getValue(data.last);
      _drawValueText(canvas, size, currentValue);
    }
  }

  void _drawGrid(Canvas canvas, Size size, double minValue, double maxValue) {
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    // 水平网格线
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 垂直网格线
    for (int i = 0; i <= 5; i++) {
      final x = size.width * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  void _drawValueText(Canvas canvas, Size size, double value) {
    final textSpan = TextSpan(
      text: value.toStringAsFixed(2),
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final offset = Offset(
      size.width - textPainter.width - 8,
      4,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant IMUWaveformPainter oldDelegate) {
    return oldDelegate.data != data || 
           oldDelegate.type != type ||
           oldDelegate.color != color;
  }
}

/// 3D方向球绘制器
class OrientationSpherePainter extends CustomPainter {
  final IMUSensorData? data;
  final Color primaryColor;
  final Color secondaryColor;

  OrientationSpherePainter({
    this.data,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;

    // 简约化：只绘制半透明外圈
    final borderPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, borderPaint);

    // 绘制装饰性中心圆
    canvas.drawCircle(center, 4, Paint()..color = primaryColor.withValues(alpha: 0.2));

    if (data != null) {
      // 这里的逻辑保持，但视觉效果调轻
      final pitch = data!.pitch;
      final roll = data!.roll;

      // 限制点在圆周内
      final limit = radius * 0.85;
      final gravityX = center.dx + math.sin(roll) * limit;
      final gravityY = center.dy + math.sin(pitch) * limit;

      // 绘制追踪阴影
      final shadowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(gravityX, gravityY), 12, shadowPaint);

      // 绘制现代感十足的核心点
      final pointPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(gravityX, gravityY), 5, pointPaint);
      
      // 增加一个外环
      final ringPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(gravityX, gravityY), 10, ringPaint);
    }
  }
      
      canvas.drawCircle(Offset(gravityX, gravityY), 8, pointPaint);

      // 绘制重力线
      final linePaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.5)
        ..strokeWidth = 2;
      canvas.drawLine(center, Offset(gravityX, gravityY), linePaint);

      // 绘制坐标轴
      _drawAxis(canvas, center, radius, pitch, roll);

      // 绘制数值
      _drawOrientationText(canvas, size, pitch, roll);
    }
  }

  void _drawAxis(Canvas canvas, Offset center, double radius, double pitch, double roll) {
    final axisLength = radius * 0.6;
    
    // X轴 (红色)
    final xPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.8)
      ..strokeWidth = 3;
    final xEnd = Offset(
      center.dx + math.cos(roll) * axisLength,
      center.dy + math.sin(roll) * axisLength * 0.3,
    );
    canvas.drawLine(center, xEnd, xPaint);

    // Y轴 (绿色)
    final yPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.8)
      ..strokeWidth = 3;
    final yEnd = Offset(
      center.dx - math.sin(pitch) * axisLength * 0.3,
      center.dy + math.cos(pitch) * axisLength,
    );
    canvas.drawLine(center, yEnd, yPaint);

    // Z轴 (蓝色) - 垂直于屏幕
    final zPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.8)
      ..strokeWidth = 3;
    final zEnd = Offset(center.dx, center.dy - axisLength * 0.5);
    canvas.drawLine(center, zEnd, zPaint);
  }

  void _drawOrientationText(Canvas canvas, Size size, double pitch, double roll) {
    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: 'Pitch: ${(pitch * 180 / math.pi).toStringAsFixed(1)}°\n',
          style: const TextStyle(color: Colors.green, fontSize: 10),
        ),
        TextSpan(
          text: 'Roll: ${(roll * 180 / math.pi).toStringAsFixed(1)}°',
          style: const TextStyle(color: Colors.red, fontSize: 10),
        ),
      ],
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(8, size.height - textPainter.height - 8));
  }

  @override
  bool shouldRepaint(covariant OrientationSpherePainter oldDelegate) {
    return oldDelegate.data?.timestamp != data?.timestamp;
  }
}

/// 运动指示器绘制器
class MotionIndicatorPainter extends CustomPainter {
  final MotionType motionType;
  final double confidence;
  final double size;

  MotionIndicatorPainter({
    required this.motionType,
    required this.confidence,
    this.size = 100,
  });

  Color get _motionColor {
    switch (motionType) {
      case MotionType.stationary:
        return Colors.grey;
      case MotionType.moving:
        return Colors.teal;
      case MotionType.walking:
        return Colors.green;
      case MotionType.running:
        return Colors.blue;
      case MotionType.shake:
        return Colors.orange;
      case MotionType.vigorousShake:
        return Colors.deepOrange;
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

  String get _motionText {
    switch (motionType) {
      case MotionType.stationary:
        return '静止';
      case MotionType.moving:
        return '轻微移动';
      case MotionType.walking:
        return '行走';
      case MotionType.running:
        return '跑步';
      case MotionType.shake:
        return '摇晃';
      case MotionType.vigorousShake:
        return '剧烈摇晃';
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

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = math.min(canvasSize.width, canvasSize.height) / 2 - 10;

    // 绘制背景圆
    final bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 绘制进度弧
    final progressPaint = Paint()
      ..color = _motionColor
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressAngle = 2 * math.pi * confidence;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi / 2,
      progressAngle,
      false,
      progressPaint,
    );

    // 绘制中心圆
    final centerPaint = Paint()
      ..color = _motionColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.6, centerPaint);

    // 绘制状态文字
    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: '$_motionText\n',
          style: TextStyle(
            color: _motionColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(
          text: '${(confidence * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: _motionColor.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: radius * 1.2);
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant MotionIndicatorPainter oldDelegate) {
    return oldDelegate.motionType != motionType ||
           oldDelegate.confidence != confidence;
  }
}
