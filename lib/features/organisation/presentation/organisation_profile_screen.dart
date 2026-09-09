import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../routing/app_routes.dart';
import '../../../services/service_providers.dart';
import '../data/organisation_repository.dart';

class OrganisationProfileScreen extends ConsumerWidget {
  const OrganisationProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authServiceProvider).currentUser?.email ?? 'Unknown';
    final statsAsync = ref.watch(organisationDashboardStatsProvider);
    final scopeAsync = ref.watch(myCredentialScopeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: statsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => const ErrorView(message: 'Could not load organisation profile.'),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'Organisation'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DetailRow(label: 'Name', value: stats.organisationName),
                  DetailRow(label: 'Access tier', value: stats.accessTier),
                  DetailRow(label: 'Verified', value: stats.verified ? 'Yes' : 'No'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'User'),
            AppCard(
              child: DetailRow(label: 'Email', value: email),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Your verification scope'),
            Text(
              'Your staff can only ever verify these credential types for a citizen, '
              'regardless of what else is on their record.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            scopeAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => const Text('Could not load your verification scope.'),
              data: (types) {
                if (types.isEmpty) {
                  return const EmptyState(
                    icon: Icons.block_outlined,
                    title: 'No credential types approved',
                    message: 'Contact a UbuntuID administrator if this looks wrong.',
                  );
                }
                return AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < types.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.verified_outlined),
                          title: Text(types[i].displayName),
                          subtitle: Text(types[i].issuingDepartment),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Team'),
            ListItemCard(
              title: 'Colleagues',
              subtitle: 'Manage your organisation\'s users',
              leadingIcon: Icons.group_outlined,
              onTap: () => context.push(AppRoutes.organisationColleagues),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Account'),
            ListItemCard(
              title: 'Settings',
              subtitle: 'Account, security, notifications, privacy',
              leadingIcon: Icons.settings_outlined,
              onTap: () => context.push(AppRoutes.settings),
            ),
          ],
        ),
      ),
    );
  }
}
