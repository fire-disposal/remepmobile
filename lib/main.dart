import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'app_module.dart';
import 'core/theme/app_theme.dart';
import 'l10n/strings.g.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化国际化
  Strings.init(AppLocale.zhCn);

  runApp(
    ModularApp(
      module: AppModule(),
      child: const AppWidget(),
    ),
  );
}

/// 应用主 Widget
class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: Modular.routerConfig,
    );
  }
}