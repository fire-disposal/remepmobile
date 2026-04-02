import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../app_sections.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int get _selectedIndex {
    final currentPath = Modular.to.path;
    final index = appSections.indexWhere((item) => currentPath.startsWith(item.fullRoute));
    return index >= 0 ? index : 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) => Modular.to.navigate(appSections[index].fullRoute),
            leading: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Icon(
                Icons.admin_panel_settings_outlined,
                size: 30,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            destinations: appSections
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: Text(appSections[selectedIndex].label),
                actions: [
                  IconButton(
                    tooltip: '设置',
                    onPressed: () => Modular.to.navigate('/app/settings'),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              body: const RouterOutlet(),
            ),
          ),
        ],
      ),
    );
  }
}
