import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/animated_count.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
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
            SizedBox(height: 200, child: ShimmerStatCardsPlaceholder(count: 2)),
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
          const SectionHeader(title: 'System overview'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _StatCard(
                label: 'Citizens',
                value: stats.totalCitizens,
                icon: Icons.groups_outlined,
                onTap: () => context.go('${AppRoutes.adminUsers}?role=citizen'),
              ),
              _StatCard(
                label: 'Department officials',
                value: stats.departmentOfficials,
                icon: Icons.badge_outlined,
                onTap: () => context.go('${AppRoutes.adminUsers}?role=departmentOfficial'),
              ),
              _StatCard(
                label: 'Organisations',
                value: stats.organisations,
                icon: Icons.apartment_outlined,
                onTap: () => context.go(AppRoutes.adminOrganisations),
              ),
              _StatCard(
                label: 'Pending verifications',
                value: stats.pendingVerifications,
                icon: Icons.fact_check_outlined,
                onTap: () => context.push(AppRoutes.adminVerification),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Citizens'),
          AppCard(
            onTap: () => context.push(AppRoutes.adminCitizenSearch),
            child: const Row(
              children: [
                Icon(Icons.person_search_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Search a citizen by ID number')),
                Icon(Icons.chevron_right),
              ],
            ),
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
            onTap: () => context.push(AppRoutes.adminAnalytics),
            child: const Row(
              children: [
                Icon(Icons.bar_chart_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Analytics')),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          AppCard(
            onTap: () => context.push(AppRoutes.adminHouseholdRecords),
            child: const Row(
              children: [
                Icon(Icons.home_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Household records')),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, this.onTap});

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const Spacer(),
          AnimatedCount(value: value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
