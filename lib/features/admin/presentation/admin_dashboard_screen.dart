import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/overview_strip.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../routing/app_routes.dart';
import '../data/admin_repository.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return statsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 92, child: ShimmerStatCardsPlaceholder()),
            SizedBox(height: 20),
            Expanded(child: ShimmerListPlaceholder(itemCount: 3, padding: EdgeInsets.zero)),
          ],
        ),
      ),
      error: (error, _) => ErrorView(
        message: 'Could not load dashboard.',
        onRetry: () => ref.invalidate(adminStatsProvider),
      ),
      data: (stats) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(
            title: 'System overview',
            action: TextButton(
              onPressed: () => context.go(AppRoutes.adminReports),
              child: const Text('View full report'),
            ),
          ),
          OverviewStrip(
            items: [
              OverviewItem(
                label: 'Citizens',
                value: stats.totalCitizens,
                icon: Icons.groups_outlined,
                onTap: () => context.go('${AppRoutes.adminUsers}?role=citizen'),
              ),
              OverviewItem(
                label: 'Department officials',
                value: stats.departmentOfficials,
                icon: Icons.badge_outlined,
                onTap: () => context.go('${AppRoutes.adminUsers}?role=departmentOfficial'),
              ),
              OverviewItem(
                label: 'Organisations',
                value: stats.organisations,
                icon: Icons.apartment_outlined,
                onTap: () => context.go(AppRoutes.adminOrganisations),
              ),
              OverviewItem(
                label: 'Pending verifications',
                value: stats.pendingVerifications,
                icon: Icons.fact_check_outlined,
                onTap: () => context.push(AppRoutes.adminVerification),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _QueueCard(
            label: 'Organisations pending review',
            icon: Icons.pending_actions_outlined,
            count: ref.watch(pendingOrganisationsProvider).value?.length,
            route: AppRoutes.adminPendingOrganisations,
          ),
          const SizedBox(height: 10),
          _QueueCard(
            label: 'Staff requests from organisations',
            icon: Icons.how_to_reg_outlined,
            count: ref.watch(adminStaffRequestsProvider).value?.where((r) => r.status == 'pending').length,
            route: AppRoutes.adminStaffRequests,
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Needs attention'),
          AppCard(
            onTap: () => context.push(AppRoutes.adminFlaggedRecords),
            child: Row(
              children: [
                Icon(Icons.flag_outlined, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                Expanded(child: Text('${stats.flaggedRecords} flagged records awaiting review')),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            onTap: () => context.push(AppRoutes.adminAppeals),
            child: const Row(
              children: [
                Icon(Icons.gavel_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Appeals lodged by departments')),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            onTap: () => context.push(AppRoutes.adminFeedback),
            child: const Row(
              children: [
                Icon(Icons.feedback_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Citizen feedback')),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: 'System activity',
            action: TextButton(
              onPressed: () => context.go(AppRoutes.adminAudit),
              child: const Text('View audit log'),
            ),
          ),
          AppCard(
            child: Text('${stats.recentAuditEvents} events recorded in the last 30 days'),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Oversight'),
          AppCard(
            onTap: () => context.push(AppRoutes.adminComplianceAudits),
            child: const Row(
              children: [
                Icon(Icons.fact_check_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Compliance audits')),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a review queue (pending organisations, staff requests), with a
/// live count badge that drops as items are decided.
class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.label, required this.icon, required this.count, required this.route});

  final String label;
  final IconData icon;
  final int? count;
  final String route;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: () => context.push(route),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: count > 0 ? scheme.secondary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: count > 0 ? scheme.onSecondary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
