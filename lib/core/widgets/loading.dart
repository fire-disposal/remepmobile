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
    return GestureDetector(
      onTap: onDismiss,
      child: Material(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator()
                    .animate()
                    .fadeIn(duration: 200.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 100.ms),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 200.ms).scale(
                begin: const Offset(0.9, 0.9),
                curve: Curves.easeOut,
              ),
        ),
      ),
    );
  }
}