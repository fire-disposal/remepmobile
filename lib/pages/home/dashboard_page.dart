import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/widgets.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const _modules = [
    _ModuleItem(
      title: 'IMU 运动监测',
      icon: Icons.accessibility_new_rounded,
      color: Colors.deepPurple,
      route: '/app/imu',
      description: '使用手机内置传感器进行运动检测与跌倒识别',
    ),
    _ModuleItem(
      title: '视觉跌倒检查',
      icon: Icons.camera_enhance_rounded,
      color: Colors.pinkAccent,
      route: '/app/vision',
      description: '通过边缘计算模型进行视觉动作捕捉',
    ),
    _ModuleItem(
      title: '蓝牙设备扫描',
      icon: Icons.bluetooth_audio_rounded,
      color: Colors.blueAccent,
      route: '/app/bluetooth/scanner',
      description: '扫描周边 BLE 设备并查看信号强度',
    ),
    _ModuleItem(
      title: '全局事件中心',
      icon: Icons.event_note_rounded,
      color: Colors.orangeAccent,
      route: '/app/events',
      description: '统一查询 IMU / 视觉检查事件',
    ),
    _ModuleItem(
      title: 'MQTT 全局配置',
      icon: Icons.wifi_tethering_rounded,
      color: Colors.teal,
      route: '/app/mqtt',
      description: '统一设置 Broker 与全局消息 Topic 前缀',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'ReMep 工作台',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/app/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _WaterfallCard(item: _modules[index]),
                childCount: _modules.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  final String description;

  const _ModuleItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
    required this.description,
  });
}

class _WaterfallCard extends StatelessWidget {
  final _ModuleItem item;
  const _WaterfallCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 优化：将颜色计算移出 build 或提前确定核心样式，避免频繁 color.withValues
    final iconBgColor = item.color.withValues(alpha: 0.08);
    final descriptionColor = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6);
    final arrowColor = theme.dividerColor.withValues(alpha: 0.5);

    return RepaintBoundary(
      child: ModernCard(
        margin: const EdgeInsets.only(bottom: 20),
        padding: EdgeInsets.zero, // 使用 ModernCard 内部 InkWell 后的 Padding
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push(item.route),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(item.icon, color: item.color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: TextStyle(
                        color: descriptionColor,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: arrowColor,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
