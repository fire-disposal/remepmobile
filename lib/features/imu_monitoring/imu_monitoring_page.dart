import 'package:flutter/material.dart';
import '../../core/widgets/widgets.dart';
import '../../core/widgets/bluetooth_picker.dart';

class ImuMonitoringPage extends StatelessWidget {
  const ImuMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IMU 跌倒监测'),
      ),
      body: EmptyState(
        icon: Icons.accessibility_new_rounded,
        title: 'IMU 监测就绪',
        subtitle: '连接蓝牙传感器以获取重力、角速度数据进行实时监测。',
        actionText: '连接设备',
        onAction: () => BluetoothPickerSheet.show(context),
      ),
    );
  }
}
