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

/// 内部模块注册表：跌倒检测和模拟数据发送为核心功能。
const appSections = <AppSection>[
  AppSection(label: '跌倒模拟', icon: Icons.elderly_outlined, childPath: '/fall-detector'),
  AppSection(label: 'MQTT 调试', icon: Icons.developer_mode_outlined, childPath: '/mqtt-debug'),
  AppSection(label: '控制台', icon: Icons.dashboard_outlined, childPath: '/dashboard'),
  AppSection(label: '设置', icon: Icons.settings_outlined, childPath: '/settings'),
];
