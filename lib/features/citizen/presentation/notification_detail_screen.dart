import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/app_routes.dart';
import '../data/citizen_repository.dart';

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
          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: AppCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notification.message, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      DetailRow(label: 'Channel', value: notification.channel.toUpperCase()),
                      DetailRow(label: 'Delivery status', value: notification.deliveryStatus),
                      DetailRow(label: 'Received', value: AppFormatters.dateTime(notification.createdAt)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
