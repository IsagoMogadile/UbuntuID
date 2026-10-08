import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/app_routes.dart';
import '../data/citizen_repository.dart';

class NotificationsListScreen extends ConsumerWidget {
  const NotificationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to home',
          onPressed: () => context.go(AppRoutes.citizenDashboard),
        ),
        title: const Text('Notifications'),
      ),
      body: notificationsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load your notifications.',
          onRetry: () => ref.invalidate(notificationsControllerProvider),
        ),
        data: (notifications) => notifications.isEmpty
            ? const EmptyState(icon: Icons.notifications_none_outlined, title: 'No notifications')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return ListItemCard(
                    title: notification.message,
                    subtitle: '${notification.channel.toUpperCase()} • '
                        '${AppFormatters.dateTime(notification.createdAt)}',
                    leadingIcon: notification.isRead
                        ? Icons.notifications_none_outlined
                        : Icons.notifications_active_outlined,
                    trailing: notification.isRead ? null : const _Dot(),
                    onTap: () =>
                        context.push('${AppRoutes.citizenNotifications}/${notification.notificationId}'),
                  );
                },
              ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
    );
  }
}
