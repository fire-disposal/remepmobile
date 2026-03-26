import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../l10n/strings.g.dart';

/// 应用主 Shell - 侧边栏导航风格
class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  bool _isSidebarOpen = false;
  
  // 模块配置
  final List<_ModuleConfig> _modules = [
    _ModuleConfig(
      id: 'mqtt_debug',
      title: 'MQTT 调试',
      subtitle: '连接测试与消息调试',
      icon: Icons.developer_mode,
      color: const Color(0xFF1E88E5),
      route: '/mqtt-debug',
      isVisible: true,
    ),
    // ⚠️ FallDetection 模块已暂时禁用
    // _ModuleConfig(
    //   id: 'fall_detection',
    //   title: '跌倒检测',
    //   subtitle: '实时视觉跌倒检测',
    //   icon: Icons.visibility,
    //   color: const Color(0xFFE53935),
    //   route: '/fall-detection',
    //   isVisible: true,
    // ),
    _ModuleConfig(
      id: 'fall_detector',
      title: '跌倒模拟',
      subtitle: '模拟跌倒事件发送',
      icon: Icons.sim_card,
      color: const Color(0xFFFF9800),
      route: '/fall-detector',
      isVisible: true,
    ),
    _ModuleConfig(
      id: 'settings',
      title: '设置',
      subtitle: '应用配置与偏好',
      icon: Icons.settings,
      color: const Color(0xFF7B1FA2),
      route: '/settings',
      isVisible: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 侧边栏
          _buildSidebar(context),
          
          // 主内容区
          Expanded(
            child: _buildMainContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isSidebarOpen ? 280 : 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColorsDark.surface,
            AppColorsDark.surfaceVariant,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 顶部栏
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.tertiary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.health_and_safety,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  if (_isSidebarOpen) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ReMep',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '移动健康系统',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  IconButton(
                    icon: Icon(
                      _isSidebarOpen ? Icons.chevron_left : Icons.chevron_right,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSidebarOpen = !_isSidebarOpen;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // 导航菜单
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _modules
                  .where((m) => m.isVisible)
                  .map((module) => _buildNavItem(context, module))
                  .toList(),
            ),
          ),
          
          // 底部控制
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: _isSidebarOpen
                  ? Column(
                      children: [
                        Divider(color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.edit, color: Colors.white70),
                          title: const Text(
                            '编辑模块',
                            style: TextStyle(color: Colors.white70),
                          ),
                          onTap: () => _showModuleEditor(context),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, _ModuleConfig module) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Modular.to.navigate(module.route),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.transparent,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: module.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    module.icon,
                    color: module.color,
                    size: 24,
                  ),
                ),
                if (_isSidebarOpen) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          module.subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceVariant,
            Colors.grey.shade100,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 顶部状态栏
            _buildTopBar(context),
            
            // 内容区域
            Expanded(
              child: _ModuleContent(modules: _modules),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Text(
            '欢迎使用 ReMep',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Toast.info(context, '暂无新通知'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Modular.to.navigate('/settings'),
          ),
        ],
      ),
    );
  }

  void _showModuleEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    '编辑模块显示',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _modules.length,
                itemBuilder: (context, index) {
                  final module = _modules[index];
                  return SwitchListTile(
                    title: Text(module.title),
                    subtitle: Text(module.subtitle),
                    value: module.isVisible,
                    onChanged: (value) {
                      setState(() {
                        module.isVisible = value;
                      });
                    },
                    secondary: Icon(module.icon, color: module.color),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleConfig {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  bool isVisible;

  _ModuleConfig({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.isVisible = true,
  });
}

class _ModuleContent extends StatelessWidget {
  final List<_ModuleConfig> modules;

  const _ModuleContent({required this.modules});

  @override
  Widget build(BuildContext context) {
    final visibleModules = modules.where((m) => m.isVisible).toList();

    if (visibleModules.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.folder_open,
          title: '没有显示的模块',
          subtitle: '请在侧边栏中编辑模块显示设置',
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: visibleModules.length,
        itemBuilder: (context, index) {
          final module = visibleModules[index];
          return _DashboardCard(module: module)
              .animate()
              .fadeIn(delay: Duration(milliseconds: 100 + (index * 100)))
              .slideY(begin: 0.2, curve: Curves.easeOut);
        },
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final _ModuleConfig module;

  const _DashboardCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Modular.to.navigate(module.route),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                module.color,
                Color.lerp(module.color, Colors.white, 0.3)!,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: module.color.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(module.icon, color: Colors.white, size: 28),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                module.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                module.subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
