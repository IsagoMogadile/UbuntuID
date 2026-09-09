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

class FlaggedRecordsListScreen extends ConsumerWidget {
  const FlaggedRecordsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagsAsync = ref.watch(adminFlaggedRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Flagged Records')),
      body: flagsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load flagged records.',
          onRetry: () => ref.invalidate(adminFlaggedRecordsProvider),
        ),
        data: (flags) {
          if (flags.isEmpty) {
            return const EmptyState(icon: Icons.flag_outlined, title: 'No flagged records');
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: flags.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final flag = flags[index];
              return ListItemCard(
                title: flag.citizenDisplayName,
                subtitle: '${flag.reason}\n${AppFormatters.date(flag.raisedAt)}',
                leadingIcon: Icons.flag_outlined,
                trailing: StatusBadge.fromStatus(flag.status),
                onTap: () => context.push('${AppRoutes.adminFlaggedRecords}/${flag.flagId}'),
              );
            },
          );
        },
      ),
    );
  }
}
