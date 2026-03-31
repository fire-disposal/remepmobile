import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../../core/widgets.dart';
import '../../../../core/theme.dart';
import '../../../../l10n/strings.g.dart';
import '../controllers/settings_controller.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.settings),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: Modular.get<SettingsController>(),
        builder: (context, _) {
          final controller = Modular.get<SettingsController>();
          final state = controller.state;

          return ListView(
            children: [
              // 用户信息卡片
              _buildUserCard(context),

              // 外观设置
              _buildSectionHeader(context, '外观'),
              ActionCard(
                title: Strings.theme,
                subtitle: _getThemeModeText(state.themeMode),
                icon: Icons.palette_outlined,
                color: const Color(0xFF7B1FA2),
                onTap: () => _showThemeDialog(context, controller, state),
              ),

              // 语言设置
              _buildSectionHeader(context, Strings.language),
              ActionCard(
                title: Strings.language,
                subtitle: '简体中文',
                icon: Icons.language,
                color: const Color(0xFF1E88E5),
                onTap: () => Toast.info(context, '语言切换功能开发中'),
              ),

              // 通知设置
              _buildSectionHeader(context, '通知'),
              _buildSwitchTile(
                context,
                icon: Icons.notifications_outlined,
                title: '推送通知',
                subtitle: '接收健康提醒和设备通知',
                value: state.isNotificationEnabled,
                onChanged: (value) {
                  controller.toggleNotification(value);
                  Toast.info(context, value ? '已开启通知' : '已关闭通知');
                },
              ),
              _buildSwitchTile(
                context,
                icon: Icons.email_outlined,
                title: '邮件通知',
                subtitle: '接收邮件提醒',
                value: state.isEmailNotificationEnabled,
                onChanged: (value) {
                  controller.toggleEmailNotification(value);
                  Toast.info(context, value ? '已开启邮件通知' : '已关闭邮件通知');
                },
              ),

              // 隐私与安全
              _buildSectionHeader(context, '隐私与安全'),
              ActionCard(
                title: '隐私政策',
                subtitle: '查看隐私政策',
                icon: Icons.privacy_tip_outlined,
                color: const Color(0xFF43A047),
                onTap: () => Toast.info(context, '隐私政策页面开发中'),
              ),
              ActionCard(
                title: '用户协议',
                subtitle: '查看用户协议',
                icon: Icons.description_outlined,
                color: const Color(0xFFFF9800),
                onTap: () => Toast.info(context, '用户协议页面开发中'),
              ),

              // 关于
              _buildSectionHeader(context, Strings.about),
              ActionCard(
                title: Strings.about,
                subtitle: '版本 1.0.0',
                icon: Icons.info_outline,
                color: const Color(0xFF607D8B),
                onTap: () => _showAboutDialog(context),
              ),

              const SizedBox(height: 24),

              // 退出登录
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _showLogoutDialog(context, controller),
                  icon: const Icon(Icons.logout),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(Strings.logout),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withBlue(180),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(
                Icons.person,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '用户名',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'user@example.com',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ModernCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  String _getThemeModeText(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Strings.systemMode;
      case AppThemeMode.light:
        return Strings.lightMode;
      case AppThemeMode.dark:
        return Strings.darkMode;
    }
  }

  void _showThemeDialog(
    BuildContext context,
    SettingsController controller,
    SettingsState state,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Strings.theme),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            return RadioListTile<AppThemeMode>(
              title: Text(_getThemeModeText(mode)),
              value: mode,
              groupValue: state.themeMode,
              onChanged: (value) {
                if (value != null) {
                  controller.setThemeMode(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: Strings.appName,
        applicationVersion: '1.0.0',
        applicationLegalese: '© 2024 HealthTech',
        children: const [
          SizedBox(height: 16),
          Text('移动健康管理系统'),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, SettingsController controller) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(Strings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await controller.logout();
              if (context.mounted) {
                Toast.success(context, '已退出登录');
                Modular.to.navigate('/auth');
              }
            },
            child: Text(Strings.confirm),
          ),
        ],
      ),
    );
  }
}