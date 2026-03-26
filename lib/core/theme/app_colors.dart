import 'package:flutter/material.dart';

/// 应用颜色定义
/// 基于Material 3设计规范
class AppColors {
  AppColors._();

  // 主色调 - 健康蓝
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryLight = Color(0xFF64B5F6);
  static const Color primaryDark = Color(0xFF1976D2);

  // 次要色调 - 活力绿
  static const Color secondary = Color(0xFF4CAF50);
  static const Color secondaryLight = Color(0xFF81C784);
  static const Color secondaryDark = Color(0xFF388E3C);

  // 强调色 - 温暖橙
  static const Color tertiary = Color(0xFFFF9800);
  static const Color tertiaryLight = Color(0xFFFFB74D);
  static const Color tertiaryDark = Color(0xFFF57C00);

  // 错误色
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color errorDark = Color(0xFFC62828);

  // 成功色
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFB8C00);
  static const Color info = Color(0xFF1E88E5);

  // 中性色
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color onSurfaceVariant = Color(0xFF757575);

  // 分隔线
  static const Color divider = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF424242);

  // 健康数据颜色
  static const Color heartRate = Color(0xFFE53935);
  static const Color bloodPressure = Color(0xFF1E88E5);
  static const Color bloodOxygen = Color(0xFF43A047);
  static const Color temperature = Color(0xFFFF9800);
  static const Color steps = Color(0xFF7B1FA2);
  static const Color sleep = Color(0xFF3949AB);
}

/// 深色主题颜色
class AppColorsDark {
  AppColorsDark._();

  static const Color primary = Color(0xFF64B5F6);
  static const Color primaryLight = Color(0xFF90CAF9);
  static const Color primaryDark = Color(0xFF42A5F5);

  static const Color secondary = Color(0xFF81C784);
  static const Color secondaryLight = Color(0xFFA5D6A7);
  static const Color secondaryDark = Color(0xFF66BB6A);

  static const Color tertiary = Color(0xFFFFB74D);
  static const Color tertiaryLight = Color(0xFFFFCC80);
  static const Color tertiaryDark = Color(0xFFFFA726);

  static const Color error = Color(0xFFEF5350);
  static const Color errorLight = Color(0xFFE57373);
  static const Color errorDark = Color(0xFFE53935);

  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF42A5F5);

  static const Color surface = Color(0xFF121212);
  static const Color surfaceVariant = Color(0xFF1E1E1E);
  static const Color onSurface = Color(0xFFE6E1E5);
  static const Color onSurfaceVariant = Color(0xFFB0B0B0);

  static const Color divider = Color(0xFF424242);
  static const Color dividerDark = Color(0xFF303030);
}