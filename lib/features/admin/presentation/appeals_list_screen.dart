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
import '../data/admin_repository.dart';

class AppealsListScreen extends ConsumerWidget {
  const AppealsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appealsAsync = ref.watch(adminAppealsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Appeals')),
      body: appealsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load appeals.',
          onRetry: () => ref.invalidate(adminAppealsProvider),
        ),
        data: (appeals) {
          if (appeals.isEmpty) {
            return const EmptyState(icon: Icons.gavel_outlined, title: 'No appeals lodged yet');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: appeals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final appeal = appeals[index];
              return ListItemCard(
                title: '${appeal.citizenDisplayName} • ${appeal.departmentName}',
                subtitle: '${appeal.appealReason}\n${AppFormatters.date(appeal.submittedAt)}',
                leadingIcon: Icons.gavel_outlined,
                trailing: StatusBadge.fromStatus(appeal.status),
                onTap: () => context.push('${AppRoutes.adminAppeals}/${appeal.appealId}'),
              );
            },
          );
        },
      ),
    );
  }
}
