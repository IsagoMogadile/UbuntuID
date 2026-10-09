import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppStatusTone { success, warning, error, info, neutral }

/// A small pill badge for rendering raw `status` text columns (which vary in
/// spelling across tables, e.g. `active`, `approved`, `verified`) with a
/// consistent colour language. [toneForStatus] is a display-only heuristic,
/// not business logic -- it does not validate or transform the underlying
/// value.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.tone = AppStatusTone.neutral});

  factory StatusBadge.fromStatus(String status) {
    return StatusBadge(label: _titleCase(status), tone: toneForStatus(status));
  }

  final String label;
  final AppStatusTone tone;

  static const _successStatuses = {
    'active', 'approved', 'verified', 'completed', 'issued', 'resolved',
    'matched', 'current', 'paid', 'read', 'delivered', 'confirmed', 'offered',
  };
  static const _warningStatuses = {
    'pending', 'submitted', 'in_review', 'under_review', 'processing',
    'awaiting_review', 'flagged', 'unread', 'open', 'requested', 'under_investigation',
  };
  static const _errorStatuses = {
    'rejected', 'declined', 'expired', 'revoked', 'inactive', 'failed', 'denied',
    'suspended', 'mismatch', 'closed', 'terminated',
  };
  static const _infoStatuses = {'draft', 'not_started', 'info', 'new', 'acknowledged'};

  static String _titleCase(String value) {
    final words = value.replaceAll('_', ' ').split(' ').where((w) => w.isNotEmpty);
    return words.map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
  }

  static AppStatusTone toneForStatus(String status) {
    final s = status.toLowerCase().trim();
    if (_successStatuses.contains(s)) return AppStatusTone.success;
    if (_warningStatuses.contains(s)) return AppStatusTone.warning;
    if (_errorStatuses.contains(s)) return AppStatusTone.error;
    if (_infoStatuses.contains(s)) return AppStatusTone.info;
    return AppStatusTone.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      AppStatusTone.success => (AppColors.successBg, AppColors.success),
      AppStatusTone.warning => (AppColors.warningBg, AppColors.warning),
      AppStatusTone.error => (AppColors.errorBg, AppColors.error),
      AppStatusTone.info => (AppColors.infoBg, AppColors.info),
      AppStatusTone.neutral => (AppColors.neutralBg, AppColors.neutral),
    };

    // Keyed by label so a status change (e.g. a verification request going
    // pending -> completed live) cross-fades instead of snapping.
    // An icon as well as a colour, so the status reads without colour vision.
    final icon = switch (tone) {
      AppStatusTone.success => Icons.check_circle_outline,
      AppStatusTone.warning => Icons.schedule,
      AppStatusTone.error => Icons.cancel_outlined,
      AppStatusTone.info => Icons.info_outline,
      AppStatusTone.neutral => null,
    };

    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 4),
            ],
            Flexible(child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}
