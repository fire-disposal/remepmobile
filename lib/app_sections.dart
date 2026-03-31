import 'package:flutter/material.dart';

class AppSection {
  const AppSection({
    required this.label,
    required this.icon,
    required this.childPath,
  });

  final String label;
  final IconData icon;
  final String childPath;

  String get fullRoute => '/app$childPath';
}

/// 内部模块注册表：新增业务只在这里补一项 + 对应页面路由。
const appSections = <AppSection>[
  AppSection(label: '控制台', icon: Icons.dashboard_outlined, childPath: '/dashboard'),
  AppSection(label: 'MQTT 调试', icon: Icons.developer_mode_outlined, childPath: '/mqtt-debug'),
  AppSection(label: '跌倒模拟', icon: Icons.elderly_outlined, childPath: '/fall-detector'),
  AppSection(label: '设置', icon: Icons.settings_outlined, childPath: '/settings'),
];
