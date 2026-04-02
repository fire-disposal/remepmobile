import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_sections.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key, required this.child});

  final Widget child;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final selectedIndex = appSections.indexWhere(
      (item) => currentPath.startsWith(item.fullRoute),
    );
    final safeIndex = selectedIndex >= 0 ? selectedIndex : 0;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: safeIndex,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) {
              context.go(appSections[index].fullRoute);
            },
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
                title: Text(appSections[safeIndex].label),
                actions: [
                  IconButton(
                    tooltip: '设置',
                    onPressed: () => context.go('/app/settings'),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              body: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
