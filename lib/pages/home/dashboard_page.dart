import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = [
      const _ModuleCardData(
        title: 'MQTT 数据模拟',
        subtitle: '本地模拟主题发布、频率与载荷数据。',
        route: '/app/mqtt-simulator',
        icon: Icons.hub_outlined,
      ),
      const _ModuleCardData(
        title: '视觉跌倒检测',
        subtitle: '本地摄像头检测流程与事件演练。',
        route: '/app/vision-fall-detection',
        icon: Icons.videocam_outlined,
      ),
      const _ModuleCardData(
        title: 'IMU 跌倒检测',
        subtitle: '基于惯导参数阈值的本地检测调试。',
        route: '/app/imu-fall-detection',
        icon: Icons.sensors_outlined,
      ),
      const _ModuleCardData(
        title: '蓝牙数据接收调试',
        subtitle: '模拟蓝牙数据流接收、解析和观察。',
        route: '/app/bluetooth-debug',
        icon: Icons.bluetooth_searching_outlined,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('本地测试工作台'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 1180
              ? 3
              : constraints.maxWidth > 760
                  ? 2
                  : 1;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.builder(
              itemCount: modules.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.55,
              ),
              itemBuilder: (_, index) {
                final item = modules[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push(item.route),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            child: Icon(item.icon),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            item.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.subtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          Text(
                            '进入模块 →',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ModuleCardData {
  const _ModuleCardData({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
}
