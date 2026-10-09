import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/list_search_field.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/admin_repository.dart';

/// Every organisation, searchable by name or type and filterable by
/// registration status. The search and filter stay as they were when an
/// admin comes back from an organisation's details.
class OrganisationsListScreen extends ConsumerStatefulWidget {
  const OrganisationsListScreen({super.key});

  @override
  ConsumerState<OrganisationsListScreen> createState() => _OrganisationsListScreenState();
}

class _OrganisationsListScreenState extends ConsumerState<OrganisationsListScreen> {
  static const _statuses = ['pending', 'approved', 'declined', 'revoked'];

  String _query = '';
  String? _status;

  @override
  Widget build(BuildContext context) {
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
          final shown = organisations.where((o) {
            if (_status != null && o.registrationStatus != _status) return false;
            if (_query.isEmpty) return true;
            return o.legalName.toLowerCase().contains(_query) ||
                o.organisationType.toLowerCase().contains(_query);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListSearchField(
                      hintText: 'Search by name or type',
                      onChanged: (q) => setState(() => _query = q),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('All (${organisations.length})'),
                          selected: _status == null,
                          onSelected: (_) => setState(() => _status = null),
                        ),
                        for (final status in _statuses)
                          ChoiceChip(
                            label: Text(
                              '${status[0].toUpperCase()}${status.substring(1)} '
                              '(${organisations.where((o) => o.registrationStatus == status).length})',
                            ),
                            selected: _status == status,
                            onSelected: (_) => setState(() => _status = _status == status ? null : status),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? EmptyState(
                        icon: Icons.apartment_outlined,
                        title: organisations.isEmpty ? 'No organisations yet' : 'No organisations match',
                        message: organisations.isEmpty
                            ? 'Organisations appear here once they register.'
                            : 'Try a different search or filter.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final organisation = shown[index];
                          return ListItemCard(
                            title: organisation.legalName,
                            subtitle: organisation.organisationType,
                            leadingIcon: Icons.apartment_outlined,
                            trailing: StatusBadge.fromStatus(organisation.registrationStatus),
                            onTap: () =>
                                context.push('${AppRoutes.adminOrganisations}/${organisation.organisationId}'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
