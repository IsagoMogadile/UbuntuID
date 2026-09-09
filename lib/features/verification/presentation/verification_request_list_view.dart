import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/verification_repository.dart';

/// Shared list body used by the department official, organisation and
/// administrator "Verification" screens.
class VerificationRequestListView extends ConsumerWidget {
  const VerificationRequestListView({super.key, required this.onOpen});

  final void Function(String requestId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(verificationRequestsProvider);

    return requestsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (error, _) => ErrorView(
        message: 'Could not load verification requests.',
        onRetry: () => ref.invalidate(verificationRequestsProvider),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return const EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No verification requests',
            message: 'New requests will appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(verificationRequestsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final request = requests[index];
              return ListItemCard(
                title: request.citizenDisplayName,
                subtitle: '${request.organisationName} • ${AppFormatters.date(request.requestedAt)}',
                leadingIcon: Icons.fact_check_outlined,
                trailing: StatusBadge.fromStatus(request.overallStatus),
                onTap: () => onOpen(request.requestId),
              );
            },
          ),
        );
      },
    );
  }
}
