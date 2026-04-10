import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/events/app_event.dart';
import '../../core/events/global_event_store.dart';

class EventCenterPage extends StatefulWidget {
  const EventCenterPage({super.key});

  @override
  State<EventCenterPage> createState() => _EventCenterPageState();
}

class _EventCenterPageState extends State<EventCenterPage> {
  AppEventSource? _source;
  AppEventLevel? _level;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = getIt<GlobalEventStore>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('全局事件中心'),
        actions: [
          IconButton(
            tooltip: '清空',
            onPressed: store.clear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final filtered = store.query(
            EventQuery(
              source: _source,
              level: _level,
              keyword: _searchCtrl.text,
            ),
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜索标题 / 内容',
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  DropdownButton<AppEventSource?>(
                    value: _source,
                    hint: const Text('来源'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('全部来源')),
                      ...AppEventSource.values.map(
                        (item) => DropdownMenuItem(value: item, child: Text(item.name)),
                      ),
                    ],
                    onChanged: (value) => setState(() => _source = value),
                  ),
                  DropdownButton<AppEventLevel?>(
                    value: _level,
                    hint: const Text('级别'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('全部级别')),
                      ...AppEventLevel.values.map(
                        (item) => DropdownMenuItem(value: item, child: Text(item.name)),
                      ),
                    ],
                    onChanged: (value) => setState(() => _level = value),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('暂无匹配事件'))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(item.sourceLabel),
                            ),
                            title: Text(item.title),
                            subtitle: Text(
                              '${item.message}\n${item.timestamp.toIso8601String()}',
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
