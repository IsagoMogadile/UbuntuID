import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/animated_count.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../routing/app_routes.dart';
import '../data/department_repository.dart';

class DepartmentDashboardScreen extends ConsumerWidget {
  const DepartmentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(departmentDashboardStatsProvider);

    return statsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 92, child: ShimmerStatCardsPlaceholder()),
            SizedBox(height: 20),
            Expanded(child: ShimmerListPlaceholder(itemCount: 4, padding: EdgeInsets.zero)),
          ],
        ),
      ),
      error: (error, _) => ErrorView(
        message: 'Could not load dashboard.\n\nDEBUG: $error',
        onRetry: () => ref.invalidate(departmentDashboardStatsProvider),
      ),
      data: (stats) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(stats.departmentName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Overview'),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Pending',
                  value: stats.pendingVerifications,
                  icon: Icons.hourglass_top_outlined,
                  onTap: () => context.go(AppRoutes.departmentVerification),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Processed (month)',
                  value: stats.processedThisMonth,
                  icon: Icons.task_alt_outlined,
                  onTap: () => context.go(AppRoutes.departmentVerification),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Officials',
                  value: stats.activeOfficials,
                  icon: Icons.groups_outlined,
                  onTap: () => context.push(AppRoutes.departmentColleagues),
                ),
              ),
            ],
          ),
          if (stats.categoryStats.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (final item in stats.categoryStats) ...[
                  Expanded(
                    child: _StatCard(label: item.label, value: item.value, icon: item.icon),
                  ),
                  if (item != stats.categoryStats.last) const SizedBox(width: 10),
                ],
              ],
            ),
          ],
          const SizedBox(height: 20),
          const SectionHeader(title: 'Citizens'),
          AppCard(
            onTap: () => context.push(AppRoutes.departmentCitizenSearch),
            child: const Row(
              children: [
                Icon(Icons.person_search_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Search a citizen by ID number')),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            onTap: () => context.push(AppRoutes.departmentCitizenRecords),
            child: const Row(
              children: [
                Icon(Icons.folder_shared_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Manage department records for a citizen')),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: 'Pending requests',
            action: TextButton(
              onPressed: () => context.go(AppRoutes.departmentVerification),
              child: const Text('View all'),
            ),
          ),
          AppCard(
            onTap: () => context.go(AppRoutes.departmentVerification),
            child: Row(
              children: [
                const Icon(Icons.fact_check_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${stats.pendingVerifications} verification requests awaiting review'),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: stats.departmentName,
            action: TextButton(
              onPressed: () => context.push(AppRoutes.departmentServices),
              child: const Text('View all services'),
            ),
          ),
          const _DepartmentSpecialServices(),
        ],
      ),
    );
  }
}

/// The department-specific dedicated screens (Register a new citizen,
/// SAPS Wanted List/Offenders/Clearance search, ...) surfaced on the
/// dashboard too, not just buried in Department Services -- driven by the
/// same `departmentServicesProvider` so every department that has one of
/// these gets it here automatically (previously hardcoded for only 2 of
/// the 9 departments -- Home Affairs and SAPS -- see
/// docs/KNOWN_LIMITATIONS.md). The generic per-record-type services
/// (Marriage, Passport, ...) stay on the Services screen, not repeated
/// here, since they all need a citizen picked first anyway.
class _DepartmentSpecialServices extends ConsumerWidget {
  const _DepartmentSpecialServices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(departmentServicesProvider);
    return servicesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (services) {
        final special = services.where((s) => s.route != null).toList();
        if (special.isEmpty) {
          return AppCard(
            onTap: () => context.push(AppRoutes.departmentCitizenRecords),
            child: const Row(
              children: [
                Icon(Icons.folder_shared_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Manage department records for a citizen')),
                Icon(Icons.chevron_right),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < special.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              AppCard(
                onTap: () => context.push(special[i].route!),
                child: Row(
                  children: [
                    Icon(special[i].icon),
                    const SizedBox(width: 12),
                    Expanded(child: Text(special[i].name)),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],
          ],
        );
      },
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
          const SizedBox(height: 8),
          AnimatedCount(value: value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
