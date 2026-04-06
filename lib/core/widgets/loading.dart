import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Loading工具类
class Loading {
  Loading._();

  static OverlayEntry? _currentLoading;

  /// 显示Loading
  static void show(
    BuildContext context, {
    String? message,
    bool barrierDismissible = false,
  }) {
    hide(); // 先隐藏之前的

    final overlay = Overlay.of(context);
    _currentLoading = OverlayEntry(
      builder: (context) => _LoadingWidget(
        message: message,
        barrierDismissible: barrierDismissible,
        onDismiss: barrierDismissible ? hide : null,
      ),
    );

    overlay.insert(_currentLoading!);
  }

  /// 隐藏Loading
  static void hide() {
    _currentLoading?.remove();
    _currentLoading = null;
  }

  /// 是否正在显示
  static bool get isShowing => _currentLoading != null;

  /// 执行异步操作并显示Loading
  static Future<T> during<T>(
    BuildContext context,
    Future<T> future, {
    String? message,
  }) async {
    show(context, message: message);
    try {
      final result = await future;
      return result;
    } finally {
      hide();
    }
  }
}

class _LoadingWidget extends StatelessWidget {
  final String? message;
  final bool barrierDismissible;
  final VoidCallback? onDismiss;

  const _LoadingWidget({
    this.message,
    this.barrierDismissible = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: onDismiss,
      child: Material(
        color: Colors.black.withValues(alpha: 0.4), // 略微调浅背景遮罩
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 48),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28), // 遵循 M3 容器圆角
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colorScheme.primary,
                ).animate()
                    .fadeIn(duration: 200.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
                if (message != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    message!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 100.ms),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 200.ms).scale(
                begin: const Offset(0.95, 0.95),
                curve: Curves.easeOutBack,
              ),
        ),
      ),
    );
  }
}