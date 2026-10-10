import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/citizen_repository.dart';
import '../domain/notification_item.dart';

class NotificationDetailScreen extends ConsumerStatefulWidget {
  const NotificationDetailScreen({super.key, required this.notificationId});

  final String notificationId;

  @override
  ConsumerState<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends ConsumerState<NotificationDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsControllerProvider.notifier).markAsRead(widget.notificationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        // Opened with context.go from the dashboard too, so there may be no
        // route to pop back to -- always go to the notifications list.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to notifications',
          onPressed: () => context.go(AppRoutes.citizenNotifications),
        ),
        title: const Text('Notification'),
      ),
      body: notificationsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(message: 'Could not load this notification.', onRetry: () => ref.invalidate(notificationsControllerProvider)),
        data: (notifications) {
          final matches = notifications.where((n) => n.notificationId == widget.notificationId);
          final notification = matches.isEmpty ? null : matches.first;
          if (notification == null) {
            return const EmptyState(icon: Icons.search_off_outlined, title: 'Notification not found', message: 'It may have been removed, or the link is out of date. Go back and try again.');
          }

          // Sized to its content instead of filling the screen.
          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              return Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 12 : 40),
                  child: Center(
                    // Full-width scroll view (scrollbar at the window's edge), content centred.
                    child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _NotificationCard(notification: notification, compact: compact),
                  ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Display-only reading of a notification. The schema has no title/type
/// column, so the heading and icon are inferred from keywords in the real
/// message; anything unrecognised falls back to a generic heading.
class _NotificationTopic {
  const _NotificationTopic(this.heading, this.icon);

  final String heading;
  final IconData icon;

  static const _topics = <(List<String>, _NotificationTopic)>[
    (['examination results'], _NotificationTopic('Examination Results Available', Icons.school_outlined)),
    (['verification', 'verify', 'verified'], _NotificationTopic('Verification Request Update', Icons.verified_user_outlined)),
    (['feedback'], _NotificationTopic('Feedback Update', Icons.forum_outlined)),
    (['sassa', 'grant'], _NotificationTopic('Social Grant Update', Icons.volunteer_activism_outlined)),
    (['payment', 'paid', 'refund'], _NotificationTopic('Payment Update', Icons.payments_outlined)),
    (['housing', 'settlement', 'rdp'], _NotificationTopic('Housing Update', Icons.home_work_outlined)),
    (['document', 'certificate', 'passport', 'licence', 'license'], _NotificationTopic('Document Update', Icons.description_outlined)),
    (['application'], _NotificationTopic('Application Update', Icons.assignment_outlined)),
    (['password', 'login', 'sign-in', 'security'], _NotificationTopic('Account Security', Icons.lock_outline)),
  ];

  static _NotificationTopic fromMessage(String message) {
    final text = message.toLowerCase();
    for (final (keywords, topic) in _topics) {
      if (keywords.any(text.contains)) return topic;
    }
    return const _NotificationTopic('Account Update', Icons.notifications_none_outlined);
  }
}

String _friendlyDeliveryStatus(String status) {
  return switch (status.toLowerCase().trim()) {
    'delivered' => 'Delivered',
    'read' => 'Read',
    'sent' => 'Sent',
    'pending' || 'queued' => 'Awaiting delivery',
    'failed' || 'bounced' || 'undelivered' => 'Not delivered',
    final other when other.isEmpty => 'Unknown',
    final other => '${other[0].toUpperCase()}${other.substring(1).replaceAll('_', ' ')}',
  };
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.compact});

  final NotificationItem notification;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topic = _NotificationTopic.fromMessage(notification.message);
    final muted = isDark ? Colors.white70 : AppColors.charcoalMuted;
    final divider = isDark ? AppColors.borderDark : AppColors.border;

    return Container(
      padding: EdgeInsets.all(compact ? 20 : 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE2ECE5)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.35) : AppColors.greenDark.withValues(alpha: 0.07),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.green.withValues(alpha: 0.22) : AppColors.greenLight,
            ),
            child: Icon(topic.icon, size: 26, color: isDark ? const Color(0xFF7FD3A4) : AppColors.green),
          ),
          const SizedBox(height: 18),
          Text(
            topic.heading,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
          ),
          const SizedBox(height: 10),
          Text(
            notification.message,
            style: theme.textTheme.bodyLarge?.copyWith(color: muted, height: 1.55),
          ),
          const SizedBox(height: 24),
          Divider(height: 1, thickness: 1, color: divider),
          const SizedBox(height: 18),
          _DetailLine(
            icon: Icons.label_outline,
            label: 'Type',
            child: Text(notification.channelLabel, style: theme.textTheme.bodyMedium),
          ),
          _DetailLine(
            icon: Icons.local_shipping_outlined,
            label: 'Delivery status',
            child: _SoftBadge(
              label: _friendlyDeliveryStatus(notification.deliveryStatus),
              tone: StatusBadge.toneForStatus(notification.deliveryStatus),
            ),
          ),
          _DetailLine(
            icon: Icons.schedule_outlined,
            label: 'Received',
            child: Text(AppFormatters.dateTime(notification.createdAt), style: theme.textTheme.bodyMedium),
          ),
          // Results notifications lead to Government Services → Basic
          // Education → National Senior Certificate, where each certificate
          // card has its Statement of Results.
          if (notification.message.toLowerCase().contains('examination results')) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push(
                  '${AppRoutes.citizenServiceRecords}?type=NSC&title=${Uri.encodeComponent('National Senior Certificate')}',
                ),
                icon: const Icon(Icons.description_outlined),
                label: const Text('View Statement of Results'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A detail row that keeps label and value side by side, wrapping the value
/// under the label when the card is too narrow for both.
class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.label, required this.child});

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : AppColors.charcoalMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(label, style: TextStyle(color: muted, fontSize: 13.5)),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme-aware take on [StatusBadge]'s colours: the pastel fills read well
/// in light mode but glare on the dark card, so dark mode uses a tinted fill.
class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.label, required this.tone});

  final String label;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (Color bg, Color fg) = switch (tone) {
      AppStatusTone.success => (AppColors.successBg, AppColors.success),
      AppStatusTone.warning => (AppColors.warningBg, AppColors.warning),
      AppStatusTone.error => (AppColors.errorBg, AppColors.error),
      AppStatusTone.info => (AppColors.infoBg, AppColors.info),
      AppStatusTone.neutral => (AppColors.neutralBg, AppColors.neutral),
    };
    final fill = isDark ? fg.withValues(alpha: 0.22) : bg;
    final text = isDark ? Color.lerp(fg, Colors.white, 0.55)! : fg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: text, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
