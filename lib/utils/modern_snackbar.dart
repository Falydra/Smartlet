import 'package:flutter/material.dart';

class ModernSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = _getTheme(type);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              theme.icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: theme.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(
          bottom: 16, // Small gap above bottom navigation bar
          left: 16,
          right: 16,
        ),
        duration: duration,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction ?? () {},
              )
            : null,
        elevation: 6,
      ),
    );
  }

  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(context, message: message, type: SnackBarType.success, duration: duration);
  }

  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    show(context, message: message, type: SnackBarType.error, duration: duration);
  }

  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    show(context, message: message, type: SnackBarType.warning, duration: duration);
  }

  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(context, message: message, type: SnackBarType.info, duration: duration);
  }

  static _SnackBarTheme _getTheme(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return _SnackBarTheme(
          color: const Color(0xFF245C4C), // Green theme color
          icon: Icons.check_circle_rounded,
        );
      case SnackBarType.error:
        return _SnackBarTheme(
          color: const Color(0xFFD32F2F), // Red
          icon: Icons.error_rounded,
        );
      case SnackBarType.warning:
        return _SnackBarTheme(
          color: const Color(0xFFF57C00), // Orange
          icon: Icons.warning_rounded,
        );
      case SnackBarType.info:
        return _SnackBarTheme(
          color: const Color(0xFF1976D2), // Blue
          icon: Icons.info_rounded,
        );
    }
  }
}

enum SnackBarType {
  success,
  error,
  warning,
  info,
}

class _SnackBarTheme {
  final Color color;
  final IconData icon;

  _SnackBarTheme({
    required this.color,
    required this.icon,
  });
}
