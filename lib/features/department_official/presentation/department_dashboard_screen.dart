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

/// A department official never sees or acts on verification here -- an
/// organisation requests it, an automated check decides it
/// (`start_verification`/`complete_verification`), and a department
/// official's own involvement is none at all (see `docs/DECISIONS.md`).
/// This dashboard is deliberately lean: department-relevant stats, then a
/// single link into Services for everything else -- every specific
/// record-type action (Marriage, Passport, Register a new citizen, ...)
/// lives there once, not duplicated here too.
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
                  label: 'Officials',
                  value: stats.activeOfficials,
                  icon: Icons.groups_outlined,
                  onTap: () => context.push(AppRoutes.departmentColleagues),
                ),
              ),
              if (stats.categoryStats.isNotEmpty) ...[
                for (final item in stats.categoryStats) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(label: item.label, value: item.value, icon: item.icon),
                  ),
                ],
              ],
            ],
          ),
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
          const SizedBox(height: 20),
          const SectionHeader(title: 'Services'),
          AppCard(
            onTap: () => context.push(AppRoutes.departmentServices),
            child: const Row(
              children: [
                Icon(Icons.apps_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Every record type this department manages')),
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
          const SizedBox(height: 8),
          AnimatedCount(value: value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
