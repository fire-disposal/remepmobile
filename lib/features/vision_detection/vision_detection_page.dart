import 'package:flutter/material.dart';
import '../../core/widgets/widgets.dart';

class VisionDetectionPage extends StatelessWidget {
  const VisionDetectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视觉跌倒检查'),
      ),
      body: const EmptyState(
        icon: Icons.camera_enhance_rounded,
        title: '视觉监测就位',
        subtitle: '开启摄像头并加载 TFLite 模型进行骨架提取与异常姿态分析。',
        actionText: '配置模型',
      ),
    );
  }
}
