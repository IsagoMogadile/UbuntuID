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

/// Only the organisations still awaiting review, oldest application first.
/// Each opens the normal organisation detail screen to approve or decline;
/// once reviewed it drops off this list (see [pendingOrganisationsProvider]).
class PendingOrganisationsScreen extends ConsumerWidget {
  const PendingOrganisationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingOrganisationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organisations pending review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminOrganisationsProvider),
          ),
        ],
      ),
      body: pendingAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load organisations.',
          onRetry: () => ref.invalidate(adminOrganisationsProvider),
        ),
        data: (pending) {
          if (pending.isEmpty) {
            return const EmptyState(
              icon: Icons.verified_outlined,
              title: 'No organisations pending review',
              message: 'New organisation applications will appear here.',
            );
          }

          final sorted = [...pending]..sort((a, b) => a.registeredAt.compareTo(b.registeredAt));
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminOrganisationsProvider);
              await ref.read(pendingOrganisationsProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final organisation = sorted[index];
                return ListItemCard(
                  title: organisation.legalName,
                  subtitle: '${organisation.organisationType} · Applied ${AppFormatters.date(organisation.registeredAt)}',
                  leadingIcon: Icons.apartment_outlined,
                  trailing: StatusBadge.fromStatus(organisation.registrationStatus),
                  onTap: () => context.push('${AppRoutes.adminOrganisations}/${organisation.organisationId}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
