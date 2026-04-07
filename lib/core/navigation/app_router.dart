import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/settings/settings_module.dart';
import '../../features/bluetooth_scanner/bluetooth_scanner_module.dart';
import '../../pages/home/dashboard_page.dart';
import '../../pages/launch_page.dart';
import '../../features/imu_monitoring/imu_monitoring_page.dart';
import '../../features/vision_detection/vision_detection_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LaunchPage(),
    ),
    GoRoute(
      path: '/app/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/app/imu',
      builder: (context, state) => const ImuMonitoringPage(),
    ),
    GoRoute(
      path: '/app/vision',
      builder: (context, state) => const VisionDetectionPage(),
    ),
    // 注入各业务模块定义的路由
    ...BluetoothScannerModule.routes,
    ...SettingsModule.routes,
  ],
);
