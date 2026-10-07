import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/animated_count.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/horizontal_bar_list.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../routing/app_routes.dart';
import '../data/department_repository.dart';

/// A department official never sees or acts on verification here -- an
/// organisation requests it, an automated check decides it
/// (`start_verification`/`complete_verification`), and a department
/// official's own involvement is none at all (see `docs/DECISIONS.md`).
/// This dashboard is analytics only: navigation lives in the shell (Services,
/// Profile, Settings in the sidebar; citizen search in the header), so no
/// action here duplicates it. Every number comes from
/// `DepartmentRepository.getDashboardStats` -- nothing is estimated.
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
      data: (stats) {
        final byService = [...stats.recordsByService]..sort((a, b) => b.$2.compareTo(a.$2));
        return RefreshIndicator(
          onRefresh: () => ref.refresh(departmentDashboardStatsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(stats.departmentName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Overview'),
              _StatGrid(
                children: [
                  _StatCard(
                    label: 'Active officials',
                    value: stats.activeOfficials,
                    icon: Icons.groups_outlined,
                    onTap: () => context.push(AppRoutes.departmentColleagues),
                  ),
                  if (byService.isNotEmpty)
                    _StatCard(label: 'Records on file', value: stats.totalRecords, icon: Icons.folder_open_outlined),
                  for (final item in stats.categoryStats)
                    _StatCard(label: item.label, value: item.value, icon: item.icon),
                ],
              ),
              if (byService.isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionHeader(title: 'Records by service'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Records held for each service this department manages.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      HorizontalBarList(data: byService, labelWidth: 150),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Lays stat cards out 2/3/4 per row depending on available width, so the
/// Overview stays readable on a phone and doesn't stretch on desktop.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});

  final List<Widget> children;

  static const _spacing = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 4 : (width >= 560 ? 3 : 2);
        final itemWidth = (width - _spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [for (final child in children) SizedBox(width: itemWidth, child: child)],
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
