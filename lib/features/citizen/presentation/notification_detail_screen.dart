import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
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
      appBar: AppBar(title: const Text('Notification')),
      body: notificationsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => const ErrorView(message: 'Could not load this notification.'),
        data: (notifications) {
          final matches = notifications.where((n) => n.notificationId == widget.notificationId);
          final notification = matches.isEmpty ? null : matches.first;
          if (notification == null) {
            return const EmptyState(icon: Icons.search_off_outlined, title: 'Notification not found');
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              child: Column(
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
          );
        },
      ),
    );
  }
}
