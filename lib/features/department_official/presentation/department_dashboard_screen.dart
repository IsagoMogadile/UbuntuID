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
import '../domain/department_category.dart';

class DepartmentDashboardScreen extends ConsumerWidget {
  const DepartmentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(departmentDashboardStatsProvider);
    final profileAsync = ref.watch(departmentProfileProvider);
    final category = profileAsync.value?.category;

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
          if (category == DepartmentCategory.homeAffairs) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'Home Affairs'),
            AppCard(
              onTap: () => context.push(AppRoutes.departmentRegisterCitizen),
              child: const Row(
                children: [
                  Icon(Icons.person_add_alt_outlined),
                  SizedBox(width: 12),
                  Expanded(child: Text('Register a new citizen')),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
          if (category == DepartmentCategory.saps) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'SAPS'),
            AppCard(
              onTap: () => context.push(AppRoutes.departmentClearanceSearch),
              child: const Row(
                children: [
                  Icon(Icons.fingerprint_outlined),
                  SizedBox(width: 12),
                  Expanded(child: Text('Search a citizen for clearance records')),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              onTap: () => context.push(AppRoutes.departmentSapsWanted),
              child: const Row(
                children: [
                  Icon(Icons.person_search_outlined),
                  SizedBox(width: 12),
                  Expanded(child: Text('Wanted list')),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              onTap: () => context.push(AppRoutes.departmentSapsOffenders),
              child: const Row(
                children: [
                  Icon(Icons.gavel_outlined),
                  SizedBox(width: 12),
                  Expanded(child: Text('Offenders')),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
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
          const SizedBox(height: 8),
          AnimatedCount(value: value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
