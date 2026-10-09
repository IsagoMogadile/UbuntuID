import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/friendly_error.dart';

enum ToastTone { success, error, warning, info }

/// The one way UbuntuID confirms or reports something: a short toast with
/// an icon (so it reads without colour), a bold headline, an optional
/// second line, and at most one action (Retry, Undo, View...). A new toast
/// replaces the current one instead of queueing behind it.
class AppToast {
  AppToast._();

  /// "Saved", "Submitted", "Deleted": something the user did worked.
  static void success(BuildContext context, String message, {String? detail, SnackBarAction? action}) =>
      show(ScaffoldMessenger.of(context), ToastTone.success, message, detail: detail, action: action);

  /// Something failed. [error] is translated into plain words by
  /// [friendlyError] (never shown raw); [onRetry] adds a Try again button.
  static void error(BuildContext context, String message, {Object? error, VoidCallback? onRetry}) => show(
    ScaffoldMessenger.of(context),
    ToastTone.error,
    message,
    detail: error == null ? null : friendlyError(error),
    action: onRetry == null ? null : SnackBarAction(label: 'Try again', onPressed: onRetry),
  );

  /// Needs attention but nothing broke ("A job title is required.").
  static void warning(BuildContext context, String message, {String? detail}) =>
      show(ScaffoldMessenger.of(context), ToastTone.warning, message, detail: detail);

  /// Neutral progress or information ("Preparing your document…").
  static void info(BuildContext context, String message, {String? detail, Duration? duration}) =>
      show(ScaffoldMessenger.of(context), ToastTone.info, message, detail: detail, duration: duration);

  static void show(
    ScaffoldMessengerState messenger,
    ToastTone tone,
    String message, {
    String? detail,
    SnackBarAction? action,
    Duration? duration,
  }) {
    final (IconData icon, Color color) = switch (tone) {
      ToastTone.success => (Icons.check_circle, const Color(0xFF7FD3A0)),
      ToastTone.error => (Icons.error, const Color(0xFFFF9C94)),
      ToastTone.warning => (Icons.warning_amber_rounded, const Color(0xFFF2C46B)),
      ToastTone.info => (Icons.info, const Color(0xFF9CC3F0)),
    };
    // An error the user must read stays longer; a confirmation goes quickly.
    final shownFor =
        duration ??
        switch (tone) {
          ToastTone.error => const Duration(seconds: 8),
          ToastTone.warning => const Duration(seconds: 6),
          _ => const Duration(seconds: 4),
        };
    final hasDetail = detail != null && detail.isNotEmpty && detail != message;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: shownFor,
          backgroundColor: AppColors.charcoal,
          showCloseIcon: tone == ToastTone.error || tone == ToastTone.warning,
          closeIconColor: Colors.white70,
          action: action == null
              ? null
              : SnackBarAction(label: action.label, onPressed: action.onPressed, textColor: AppColors.gold),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(color: Colors.white, fontWeight: hasDetail ? FontWeight.w700 : FontWeight.w500),
                    ),
                    if (hasDetail) ...[
                      const SizedBox(height: 2),
                      Text(detail, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}
