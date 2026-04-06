import 'package:flutter/material.dart';

import 'vision_detection_models.dart';

class DetectionOverlayPainter extends CustomPainter {
  DetectionOverlayPainter(this.boxes);

  final List<DetectionBox> boxes;

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
  }

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter oldDelegate) {
    return oldDelegate.boxes != boxes;
  }
}
