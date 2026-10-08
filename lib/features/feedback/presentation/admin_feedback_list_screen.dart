import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/feedback_repository.dart';
import '../domain/feedback_item.dart';

class AdminFeedbackListScreen extends ConsumerWidget {
  const AdminFeedbackListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(adminFeedbackProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Citizen feedback')),
      body: feedbackAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load feedback.',
          onRetry: () => ref.invalidate(adminFeedbackProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(icon: Icons.feedback_outlined, title: 'No feedback received yet');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final stars = item.rating == null ? '' : ' • ${'★' * item.rating!}';
              return ListItemCard(
                title: '${feedbackLabel(item.feedbackType)} • ${item.subjectLabel}',
                subtitle: '${item.citizenDisplayName}$stars\n${AppFormatters.date(item.createdAt)}',
                leadingIcon: switch (item.feedbackType) {
                  'complaint' => Icons.report_outlined,
                  'compliment' => Icons.thumb_up_outlined,
                  _ => Icons.lightbulb_outline,
                },
                trailing: StatusBadge.fromStatus(item.status),
                onTap: () => context.push('${AppRoutes.adminFeedback}/${item.feedbackId}'),
              );
            },
          );
        },
      ),
    );
  }
}
