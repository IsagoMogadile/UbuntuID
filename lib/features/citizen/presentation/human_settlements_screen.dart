import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/citizen_repository.dart';

/// Human Settlements is simulated: this screen only reads this project's
/// own Supabase tables (`housing_applications`, `housing_beneficiaries`,
/// `properties`, `title_deeds`) -- no real Human Settlements/Deeds Office
/// API is called. View-only: UbuntuID is not the housing application
/// system, so there is deliberately no "Apply for a programme" action here
/// -- housing applications are made through the department's own process.
/// See docs/PROJECT_SCOPE.md.
/// `title_deeds` is a one-to-many embed (no unique constraint on
/// `title_deeds.property_id`), so it always arrives as a `List`, even when
/// empty or holding exactly one row. Returns the first (most recently
/// created) deed's status, or null if the property has none yet.
String? _latestDeedStatus(dynamic titleDeeds) {
  if (titleDeeds is! List || titleDeeds.isEmpty) return null;
  final first = titleDeeds.first;
  if (first is! Map) return null;
  return first['deed_status'] as String?;
}

class HumanSettlementsScreen extends ConsumerWidget {
  const HumanSettlementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(housingApplicationsRawProvider);
    final propertiesAsync = ref.watch(housingBeneficiaryPropertiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Human Settlements')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(housingApplicationsRawProvider);
          ref.invalidate(housingBeneficiaryPropertiesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'My property'),
            propertiesAsync.when(
              loading: () => const LoadingIndicator(),
              error: (error, _) => ErrorView(message: 'Could not load property records.', onRetry: () => ref.invalidate(housingBeneficiaryPropertiesProvider)),
              data: (beneficiaries) {
                if (beneficiaries.isEmpty) {
                  return const EmptyState(
                    icon: Icons.home_work_outlined,
                    title: 'No property linked to your record yet', message: 'When Human Settlements links a property to your ID, it will show here.',
                  );
                }
                return Column(
                  children: [
                    for (final beneficiary in beneficiaries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DetailRow(
                                label: 'Property',
                                value: (beneficiary['properties']?['property_reference'] as String?) ?? 'Unknown',
                              ),
                              DetailRow(
                                label: 'Municipality',
                                value: (beneficiary['properties']?['municipality'] as String?) ?? 'Unknown',
                              ),
                              DetailRow(
                                label: 'Title deed status',
                                // `title_deeds` embeds as a List here (no
                                // unique constraint on title_deeds.property_id,
                                // so PostgREST treats it as one-to-many, not
                                // one-to-one) -- a property with no title
                                // deed yet is a real, valid state, not an
                                // error.
                                value: _latestDeedStatus(beneficiary['properties']?['title_deeds']) ??
                                    'Not yet registered',
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'My housing applications'),
            applicationsAsync.when(
              loading: () => const LoadingIndicator(),
              error: (error, _) => ErrorView(message: 'Could not load your applications.', onRetry: () => ref.invalidate(housingApplicationsRawProvider)),
              data: (applications) {
                if (applications.isEmpty) {
                  return const EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No housing records',
                    message: 'No housing programme records are associated with your identity yet.',
                  );
                }
                return Column(
                  children: [
                    for (final application in applications)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ListItemCard(
                          title: (application['housing_programmes']?['programme_name'] as String?) ??
                              'Human Settlements',
                          subtitle: '${application['municipality'] ?? ''}, ${application['province'] ?? ''}',
                          leadingIcon: Icons.home_work_outlined,
                          trailing: StatusBadge.fromStatus(application['application_status'] as String? ?? 'submitted'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
