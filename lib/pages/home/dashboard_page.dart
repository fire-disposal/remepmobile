import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      const _KpiItem('在线设备', '24', Icons.sensors),
      const _KpiItem('今日告警', '3', Icons.warning_amber_rounded),
      const _KpiItem('活跃用户', '12', Icons.people_alt_outlined),
      const _KpiItem('消息吞吐', '1.2k/min', Icons.insights_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '控制台',
          style: Theme.of(context).textTheme.headlineMedium,
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
