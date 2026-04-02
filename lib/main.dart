import 'package:flutter/material.dart';

import 'core/di/service_locator.dart';
import 'core/navigation/app_router.dart';
import 'core/storage/cache_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive 缓存
  await CacheStorageService().init();

  // 初始化依赖注入
  setupServiceLocator();

  runApp(const AppWidget());
}

/// 应用主 Widget
class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ReMep 移动健康',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
