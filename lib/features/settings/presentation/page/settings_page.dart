import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/permission/permission_service.dart';
import '../controllers/settings_controller.dart';

/// 设置页面 - 包含权限管理调试功能
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => getIt<SettingsController>().refreshPermissions(),
            tooltip: '刷新权限状态',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: getIt<SettingsController>(),
        builder: (context, _) {
          final controller = getIt<SettingsController>();
          final state = controller.state;

          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: [
              _buildSectionHeader(context, '界面定制'),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('主题模式'),
                trailing: Text(
                  _getThemeModeText(state.themeMode),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                onTap: () => _showThemeDialog(context, controller, state),
              ),

              _buildSectionHeader(context, '权限管理'),
              ...AppPermission.values.map((p) => _buildPermissionTile(context, controller, p, state.permissions[p])),
              
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_applications_outlined),
                title: const Text('打开系统设置'),
                subtitle: const Text('手动管理应用权限与通知'),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () => controller.openAppSettings(),
              ),

              _buildSectionHeader(context, '数据清理'),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                title: const Text('重置所有数据', style: TextStyle(color: Colors.red)),
                subtitle: const Text('清除缓存与安全存储，恢复出厂设置'),
                onTap: () => _showResetDialog(context, controller),
              ),

              _buildSectionHeader(context, '关于'),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('当前版本'),
                trailing: const Text('1.0.0'),
                onTap: () => _showAbout(context),
              ),
              
              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  Widget _buildPermissionTile(
    BuildContext context, 
    SettingsController controller, 
    AppPermission permission, 
    AppPermissionStatus? status
  ) {
    final statusColor = _getPermissionStatusColor(status);
    final statusText = _getPermissionStatusText(status);
    final isBluetooth = permission == AppPermission.bluetooth;

    return ListTile(
      dense: true,
      leading: Icon(_getPermissionIcon(permission), size: 22),
      title: Text(
        _getPermissionName(permission),
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        '${_getPermissionDeclaration(permission)}\n状态：$statusText',
        style: TextStyle(
          color: statusColor, 
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      trailing: SizedBox(
        width: 80,
        child: _buildPermissionActionButton(
          context, 
          controller, 
          permission, 
          status,
          isBluetooth: isBluetooth,
        ),
      ),
    );
  }

  /// 构建权限操作按钮
  Widget _buildPermissionActionButton(
    BuildContext context,
    SettingsController controller,
    AppPermission permission,
    AppPermissionStatus? status, {
    required bool isBluetooth,
  }) {
    // 已授权状态
    if (status == AppPermissionStatus.granted) {
      return Center(
        child: Icon(
          Icons.check_circle,
          color: Colors.green.shade600,
          size: 22,
        ),
      );
    }
    
    // 永久拒绝状态
    if (status == AppPermissionStatus.permanentlyDenied) {
      return TextButton(
        onPressed: () => controller.openAppSettings(),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('去设置', style: TextStyle(fontSize: 12)),
      );
    }
    
    // 未授权状态
    return OutlinedButton(
      onPressed: () => controller.requestPermission(permission),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('请求', style: TextStyle(fontSize: 12)),
    );
  }

  String _getPermissionName(AppPermission p) {
    switch (p) {
      case AppPermission.camera: return '摄像头';
      case AppPermission.microphone: return '麦克风';
      case AppPermission.storage: return '文件存储';
      case AppPermission.location: return '位置信息';
      case AppPermission.bluetooth: return '蓝牙连接';
      case AppPermission.notification: return '系统通知';
      case AppPermission.sensors: return '运动传感器';
      case AppPermission.activityRecognition: return '活动识别';
    }
  }

  IconData _getPermissionIcon(AppPermission p) {
    switch (p) {
      case AppPermission.camera: return Icons.camera_alt_outlined;
      case AppPermission.microphone: return Icons.mic_none_outlined;
      case AppPermission.storage: return Icons.folder_open_outlined;
      case AppPermission.location: return Icons.location_on_outlined;
      case AppPermission.bluetooth: return Icons.bluetooth_outlined;
      case AppPermission.notification: return Icons.notifications_none_outlined;
      case AppPermission.sensors: return Icons.sensors_outlined;
      case AppPermission.activityRecognition: return Icons.directions_run_outlined;
    }
  }

  String _getPermissionStatusText(AppPermissionStatus? status) {
    switch (status) {
      case AppPermissionStatus.granted: return '已授权';
      case AppPermissionStatus.denied: return '已拒绝';
      case AppPermissionStatus.permanentlyDenied: return '永久拒绝 (需去设置开启)';
      case AppPermissionStatus.restricted: return '受限';
      case AppPermissionStatus.limited: return '部分授权';
      case AppPermissionStatus.provisional: return '临时授权';
      case null: return '未知';
    }
  }

  String _getPermissionDeclaration(AppPermission permission) {
    switch (permission) {
      case AppPermission.camera:
        return '用于视觉检测与拍摄。';
      case AppPermission.microphone:
        return '用于语音采集与通话录音。';
      case AppPermission.storage:
        return '用于读取/导出本地文件（Android 13+ 将分媒体类型授权）。';
      case AppPermission.location:
        return '用于蓝牙扫描兼容（Android 11 及以下）。';
      case AppPermission.bluetooth:
        return '用于扫描与连接 BLE 设备（Android 12+ 需单独授权）。';
      case AppPermission.notification:
        return '用于系统通知与告警推送（Android 13+）。';
      case AppPermission.sensors:
        return 'IMU（加速度计/陀螺仪）无需单独弹窗授权。';
      case AppPermission.activityRecognition:
        return '用于步态/活动检测（Android 10+）。';
    }
  }

  Color _getPermissionStatusColor(AppPermissionStatus? status) {
    switch (status) {
      case AppPermissionStatus.granted: return Colors.green;
      case AppPermissionStatus.denied: return Colors.orange;
      case AppPermissionStatus.permanentlyDenied: return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getThemeModeText(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system: return '跟随系统';
      case AppThemeMode.light: return '浅色模式';
      case AppThemeMode.dark: return '深色模式';
    }
  }

  void _showThemeDialog(BuildContext context, SettingsController controller, SettingsState state) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            // ignore: deprecated_member_use
            return RadioListTile<AppThemeMode>(
              title: Text(_getThemeModeText(mode)),
              value: mode,
              // ignore: deprecated_member_use
              groupValue: state.themeMode,
              // ignore: deprecated_member_use
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

  void _showResetDialog(BuildContext context, SettingsController controller) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置系统'),
        content: const Text('这将清除所有本地缓存、配对信息和配置，操作不可逆。确定继续吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await controller.clearAllData();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清理所有数据')));
              }
            },
            child: const Text('确定重置', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'ReMep 移动健康',
      applicationVersion: '1.0.0',
      applicationIcon: const FlutterLogo(size: 48),
      applicationLegalese: '© 2026 HealthTech',
    );
  }
}
