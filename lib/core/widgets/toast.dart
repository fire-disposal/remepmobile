import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Toast类型
enum ToastType {
  info,
  success,
  warning,
  error,
}

/// Toast工具类
class Toast {
  Toast._();

  /// 显示Toast
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        duration: duration,
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration + 300.ms, () {
      overlayEntry.remove();
    });
  }

  /// 信息Toast
  static void info(BuildContext context, String message) {
    show(context, message: message, type: ToastType.info);
  }

  /// 成功Toast
  static void success(BuildContext context, String message) {
    show(context, message: message, type: ToastType.success);
  }

  /// 警告Toast
  static void warning(BuildContext context, String message) {
    show(context, message: message, type: ToastType.warning);
  }

  /// 错误Toast
  static void error(BuildContext context, String message) {
    show(context, message: message, type: ToastType.error);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.duration,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: 300.ms,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // M3 风格配置
    final bgColor = _getM3BackgroundColor(colorScheme);
    final foregroundColor = _getM3ForegroundColor(colorScheme);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 24,
      right: 24,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16), // M3 较小的容器圆角
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _getIcon(),
                    color: foregroundColor,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getM3BackgroundColor(ColorScheme colorScheme) {
    switch (widget.type) {
      case ToastType.info:
        return colorScheme.secondaryContainer;
      case ToastType.success:
        // M3 没有直接的 Success 容器，通常使用绿色调或自定义扩展
        return const Color(0xFFE8F5E9); // 浅绿
      case ToastType.warning:
        return const Color(0xFFFFF3E0); // 浅橙
      case ToastType.error:
        return colorScheme.errorContainer;
    }
  }

  Color _getM3ForegroundColor(ColorScheme colorScheme) {
    switch (widget.type) {
      case ToastType.info:
        return colorScheme.onSecondaryContainer;
      case ToastType.success:
        return const Color(0xFF2E7D32); // 深绿
      case ToastType.warning:
        return const Color(0xFFE65100); // 深橙
      case ToastType.error:
        return colorScheme.onErrorContainer;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case ToastType.info:
        return Icons.info_outline;
      case ToastType.success:
        return Icons.check_circle_outline;
      case ToastType.warning:
        return Icons.warning_amber_outlined;
      case ToastType.error:
        return Icons.error_outline;
    }
  }

  Color _getIconColor() => Colors.white;

  Color _getTextColor() => Colors.white;
}