import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/di/service_locator.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';

void main() async {
  // 确保 Flutter 绑定初始化（必须作为首行）
  WidgetsFlutterBinding.ensureInitialized();

  // 加载环境变量文件
  try {
    await dotenv.load(fileName: ".env.development");
  } catch (e) {
    debugPrint('警告: 无法加载 .env 文件: $e');
  }

  try {
    // 异步初始化所有核心依赖，且在 runApp 前确保资源就绪。
    // 这有助于减少初次访问 UI 时的卡顿感（Lazy loading 策略）。
    await setupServiceLocator();
  } catch (e) {
    debugPrint('基础设施初始化失败: $e');
  }

  runApp(const AppWidget());
}

/// 应用主 Widget
class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: getIt<ThemeModeNotifier>(),
      builder: (context, _) {
        final themeNotifier = getIt<ThemeModeNotifier>();
        return MaterialApp.router(
          title: 'ReMep 移动健康',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeNotifier.flutterThemeMode,
          routerConfig: appRouter,
        );
      },
    );
  }
}
