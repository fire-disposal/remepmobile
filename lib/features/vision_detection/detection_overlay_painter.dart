import 'package:flutter/material.dart';

import 'vision_detection_models.dart';

/// 检测框和关键点绘制器
/// 
/// 支持绘制：
/// - 人体检测框
/// - 关键点（圆点）
/// - 骨架连接线
class DetectionOverlayPainter extends CustomPainter {
  DetectionOverlayPainter(this.boxes);

  final List<DetectionBox> boxes;

  // COCO格式的骨架连接定义（基于17个关键点）
  // 格式: [起点索引, 终点索引]
  static const List<List<int>> skeletonConnections = [
    // 面部
    [0, 1], [0, 2], [1, 3], [2, 4], // 鼻子到眼睛到耳朵
    // 躯干
    [5, 6], [5, 11], [6, 12], [11, 12], // 肩膀到臀部
    // 左臂
    [5, 7], [7, 9], // 左肩到左肘到左腕
    // 右臂
    [6, 8], [8, 10], // 右肩到右肘到右腕
    // 左腿
    [11, 13], [13, 15], // 左臀到左膝到左踝
    // 右腿
    [12, 14], [14, 16], // 右臀到右膝到右踝
  ];

  // 不同部位的颜色
  static final Map<String, Color> keypointColors = {
    'face': Colors.yellow,      // 面部关键点
    'body': Colors.cyan,        // 躯干关键点
    'left_arm': Colors.orange,  // 左臂
    'right_arm': Colors.pink,   // 右臂
    'left_leg': Colors.green,   // 左腿
    'right_leg': Colors.purple, // 右腿
  };

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    final fillPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    for (final box in boxes) {
      // 优先绘制关键点（MoveNet等姿态模型）
      if (box.hasKeyPoints) {
        _drawKeyPoints(canvas, size, box.keyPoints!);
        // 有关键点的模型不绘制检测框，只显示标签
        _drawLabelOnly(canvas, size, box);
      } else {
        // 没有关键点的模型（备用模式）绘制检测框
        _drawDetectionBox(canvas, size, box, borderPaint, fillPaint);
      }
    }
  }

  /// 仅绘制标签（用于关键点模型）
  void _drawLabelOnly(Canvas canvas, Size size, DetectionBox box) {
    // 计算标签位置（使用检测框中心上方）
    final centerX = (box.normalizedRect.left + box.normalizedRect.width / 2) * size.width;
    final topY = box.normalizedRect.top * size.height;
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: '${box.label} ${(box.confidence * 100).toStringAsFixed(0)}%',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          shadows: [
            Shadow(
              offset: Offset(0, 1),
              blurRadius: 3,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    )..layout();

    final tagRect = Rect.fromCenter(
      center: Offset(centerX, (topY - 15).clamp(20, size.height - 20)),
      width: textPainter.width + 16,
      height: 24,
    );

    // 绘制半透明背景
    canvas.drawRRect(
      RRect.fromRectAndRadius(tagRect, const Radius.circular(12)),
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    
    textPainter.paint(
      canvas, 
      Offset(tagRect.left + 8, tagRect.top + 4),
    );
  }

  /// 绘制检测框
  void _drawDetectionBox(Canvas canvas, Size size, DetectionBox box, 
                         Paint borderPaint, Paint fillPaint) {
    final rect = Rect.fromLTWH(
      box.normalizedRect.left * size.width,
      box.normalizedRect.top * size.height,
      box.normalizedRect.width * size.width,
      box.normalizedRect.height * size.height,
    );

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), fillPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: '${box.label} ${(box.confidence * 100).toStringAsFixed(1)}%',
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    )..layout(maxWidth: size.width * 0.8);

    final tagRect = Rect.fromLTWH(
      rect.left,
      (rect.top - 20).clamp(0, size.height - 18),
      textPainter.width + 10,
      18,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(tagRect, const Radius.circular(6)),
      Paint()..color = Colors.greenAccent,
    );
    textPainter.paint(canvas, Offset(tagRect.left + 5, tagRect.top + 1));
  }

  /// 绘制关键点
  void _drawKeyPoints(Canvas canvas, Size size, List<KeyPoint> keyPoints) {
    // 先绘制骨架连接线
    _drawSkeleton(canvas, size, keyPoints);
    
    // 绘制关键点圆点
    for (final point in keyPoints) {
      // 如果关键点置信度太低，跳过绘制
      if (point.confidence < 0.3) continue;
      
      final position = Offset(
        point.normalizedPosition.dx * size.width,
        point.normalizedPosition.dy * size.height,
      );
      
      final color = _getKeyPointColor(point.index);
      
      // 绘制外圈（白色边框）
      canvas.drawCircle(
        position,
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      
      // 绘制内圈（彩色填充）
      canvas.drawCircle(
        position,
        4,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      
      // 绘制置信度文字（小字体）
      if (point.confidence > 0.5) {
        final textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: point.name.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 8,
            ),
          ),
        )..layout();
        
        textPainter.paint(
          canvas, 
          Offset(position.dx + 8, position.dy - 8),
        );
      }
    }
  }

  /// 绘制骨架连接线
  void _drawSkeleton(Canvas canvas, Size size, List<KeyPoint> keyPoints) {
    final linePaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final connection in skeletonConnections) {
      final startIdx = connection[0];
      final endIdx = connection[1];
      
      // 确保两个关键点都存在且置信度足够
      if (startIdx >= keyPoints.length || endIdx >= keyPoints.length) continue;
      
      final startPoint = keyPoints[startIdx];
      final endPoint = keyPoints[endIdx];
      
      if (startPoint.confidence < 0.3 || endPoint.confidence < 0.3) continue;
      
      final startOffset = Offset(
        startPoint.normalizedPosition.dx * size.width,
        startPoint.normalizedPosition.dy * size.height,
      );
      
      final endOffset = Offset(
        endPoint.normalizedPosition.dx * size.width,
        endPoint.normalizedPosition.dy * size.height,
      );
      
      canvas.drawLine(startOffset, endOffset, linePaint);
    }
  }

  /// 根据关键点索引获取颜色
  Color _getKeyPointColor(int index) {
    // 面部: 0-4
    if (index <= 4) return keypointColors['face']!;
    // 肩膀: 5-6
    if (index <= 6) return keypointColors['body']!;
    // 手臂: 7-10
    if (index <= 10) return index % 2 == 1 ? keypointColors['left_arm']! : keypointColors['right_arm']!;
    // 臀部: 11-12
    if (index <= 12) return keypointColors['body']!;
    // 腿部: 13-16
    return index % 2 == 1 ? keypointColors['left_leg']! : keypointColors['right_leg']!;
  }

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter oldDelegate) {
    return oldDelegate.boxes != boxes;
  }
}
