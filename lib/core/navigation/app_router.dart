import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/local_lab/presentation/pages/bluetooth_debug_page.dart';
import '../../features/local_lab/presentation/pages/imu_fall_detection_page.dart';
import '../../features/local_lab/presentation/pages/mqtt_simulator_page.dart';
import '../../features/local_lab/presentation/pages/vision_fall_detection_page.dart';
import '../../pages/home/dashboard_page.dart';
import '../../pages/launch_page.dart';

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
      path: '/app/mqtt-simulator',
      builder: (context, state) => const MqttSimulatorPage(),
    ),
    GoRoute(
      path: '/app/vision-fall-detection',
      builder: (context, state) => const VisionFallDetectionPage(),
    ),
    GoRoute(
      path: '/app/imu-fall-detection',
      builder: (context, state) => const ImuFallDetectionPage(),
    ),
    GoRoute(
      path: '/app/bluetooth-debug',
      builder: (context, state) => const BluetoothDebugPage(),
    ),
  ],
);
