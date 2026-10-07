import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/horizontal_bar_list.dart';
import '../../../core/widgets/overview_strip.dart';
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
              OverviewStrip(
                items: [
                  OverviewItem(
                    label: 'Active officials',
                    value: stats.activeOfficials,
                    icon: Icons.groups_outlined,
                    onTap: () => context.push(AppRoutes.departmentColleagues),
                  ),
                  if (byService.isNotEmpty)
                    OverviewItem(label: 'Records on file', value: stats.totalRecords, icon: Icons.folder_open_outlined),
                  for (final item in stats.categoryStats)
                    OverviewItem(label: item.label, value: item.value, icon: item.icon),
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
