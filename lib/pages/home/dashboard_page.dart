import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      const _KpiItem('跌倒检测节点', '主功能', Icons.elderly_outlined),
      const _KpiItem('MQTT模拟发送', 'QoS 1', Icons.send_outlined),
      const _KpiItem('遥控器模拟', 'remote_controller', Icons.gamepad_outlined),
      const _KpiItem('协议', 'remipedia/devices/{sn}/{type}', Icons.route_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '模拟控制台',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '聚焦跌倒检测与 MQTT 数据构建/发送，支持自定义 Broker 域名和端口，默认无鉴权。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items
              .map(
                (item) => SizedBox(
                  width: 250,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(item.icon, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.label),
                              const SizedBox(height: 4),
                              Text(
                                item.value,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _KpiItem {
  const _KpiItem(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}
