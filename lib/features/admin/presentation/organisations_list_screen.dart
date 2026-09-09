import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/admin_repository.dart';

class OrganisationsListScreen extends ConsumerWidget {
  const OrganisationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organisationsAsync = ref.watch(adminOrganisationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Organisations')),
      body: organisationsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load organisations.',
          onRetry: () => ref.invalidate(adminOrganisationsProvider),
        ),
        data: (organisations) {
          if (organisations.isEmpty) {
            return const EmptyState(icon: Icons.apartment_outlined, title: 'No organisations found');
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: organisations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final organisation = organisations[index];
              return ListItemCard(
                title: organisation.legalName,
                subtitle: organisation.organisationType,
                leadingIcon: Icons.apartment_outlined,
                trailing: StatusBadge.fromStatus(organisation.registrationStatus),
                onTap: () => context.push('${AppRoutes.adminOrganisations}/${organisation.organisationId}'),
              );
            },
          );
        },
      ),
    );
  }
}
