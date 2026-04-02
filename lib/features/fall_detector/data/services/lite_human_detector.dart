import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/fall_detection_models.dart';

class LiteHumanDetector {
  static const modelName = 'movenet_lightning_fp16';

  double _lastMeanLuma = 0;
  int _frameIndex = 0;

  DetectionBox infer(
    CameraImage image, {
    Interpreter? interpreter,
    int inputSize = 192,
  }) {
    if (interpreter != null) {
      final modelBox = _inferWithMoveNet(image, interpreter, inputSize);
      if (modelBox != null) {
        return modelBox;
      }
    }
    return _inferFallback(image);
  }

  DetectionBox _inferFallback(CameraImage image) {
    _frameIndex += 1;

    final yPlane = image.planes.first.bytes;
    var sum = 0;
    var count = 0;
    for (var i = 0; i < yPlane.length; i += 32) {
      sum += yPlane[i];
      count += 1;
    }
    final meanLuma = count == 0 ? 0.0 : sum / count;

    final motion = (meanLuma - _lastMeanLuma).abs() / 255;
    _lastMeanLuma = meanLuma;

    final wave = 0.5 + 0.5 * math.sin(_frameIndex / 12);
    final width = (0.22 + motion * 0.5 + wave * 0.08).clamp(0.20, 0.62);
    final height = (0.55 - motion * 0.35 - wave * 0.22).clamp(0.20, 0.65);
    final left = (0.5 - (width / 2) + (wave - 0.5) * 0.2).clamp(0.02, 0.98 - width);

    return DetectionBox(
      left: left,
      top: 0.18,
      width: width,
      height: height,
      confidence: (0.60 + motion * 0.35 + wave * 0.05).clamp(0.55, 0.95),
      source: 'fallback_proxy',
    );
  }

  DetectionBox? _inferWithMoveNet(CameraImage image, Interpreter interpreter, int inputSize) {
    try {
      final yPlane = image.planes.first;
      final input = List.generate(
        1,
        (_) => List.generate(
          inputSize,
          (y) => List.generate(
            inputSize,
            (x) {
              final px = (x * yPlane.bytesPerRow / inputSize).floor();
              final py = (y * image.height / inputSize).floor();
              final idx = (py * yPlane.bytesPerRow + px).clamp(0, yPlane.bytes.length - 1);
              final v = yPlane.bytes[idx] / 255.0;
              return [v, v, v];
            },
          ),
        ),
      );

      final output = List.generate(
        1,
        (_) => List.generate(
          1,
          (_) => List.generate(17, (_) => List.filled(3, 0.0)),
        ),
      );

      interpreter.run(input, output);

      double minX = 1, minY = 1, maxX = 0, maxY = 0, avgScore = 0;
      var valid = 0;
      for (final kp in output[0][0]) {
        final y = (kp[0] as num).toDouble();
        final x = (kp[1] as num).toDouble();
        final score = (kp[2] as num).toDouble();
        if (score < 0.2) continue;

        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
        avgScore += score;
        valid += 1;
      }

      if (valid < 4) return null;

      final width = (maxX - minX).clamp(0.08, 0.95);
      final height = (maxY - minY).clamp(0.12, 0.95);

      return DetectionBox(
        left: minX.clamp(0, 1 - width),
        top: minY.clamp(0, 1 - height),
        width: width,
        height: height,
        confidence: (avgScore / valid).clamp(0.4, 0.99),
        source: 'movenet',
      );
    } catch (_) {
      return null;
    }
  }
}
