import 'package:flutter/material.dart';
import '../bluetooth/bluetooth_service.dart';
import '../di/service_locator.dart';
import 'widgets.dart';

/// 蓝牙连接选择器弹窗
class BluetoothPickerSheet extends StatefulWidget {
  const BluetoothPickerSheet({super.key});

  /// 显示蓝牙连接弹窗
  static Future<void> show(BuildContext context) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BluetoothPickerSheet(),
    );
  }

  @override
  State<BluetoothPickerSheet> createState() => _BluetoothPickerSheetState();
}

class _BluetoothPickerSheetState extends State<BluetoothPickerSheet> {
  final _bluetoothService = getIt<BluetoothService>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(Icons.bluetooth_searching_rounded, color: colorScheme.primary),
                const SizedBox(width: 16),
                Text(
                  '发现设备',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _bluetoothService.statusStream,
              builder: (context, snapshot) {
                // 如果蓝牙未开启，显示空状态
                return const EmptyState(
                  icon: Icons.bluetooth_disabled_rounded,
                  title: '未检测到设备',
                  subtitle: '请确保蓝牙已开启且设备处于广播状态',
                  actionText: '重新扫描',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
