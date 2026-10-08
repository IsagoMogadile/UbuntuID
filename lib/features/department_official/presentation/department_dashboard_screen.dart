import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/overview_strip.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../routing/app_routes.dart';
import '../../reports/domain/report_data.dart';
import '../../reports/presentation/report_activity_card.dart';
import '../data/department_repository.dart';

/// A department official never sees or acts on verification here -- an
/// organisation requests it, an automated check decides it
/// (`start_verification`/`complete_verification`), and a department
/// official's own involvement is none at all (see `docs/DECISIONS.md`).
/// This dashboard is analytics only: navigation lives in the shell (Services,
/// Reports, Settings in the sidebar; citizen search and Profile in the header), so no
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
                  if (stats.recordsByService.isNotEmpty)
                    OverviewItem(label: 'Records on file', value: stats.totalRecords, icon: Icons.folder_open_outlined),
                  for (final item in stats.categoryStats)
                    OverviewItem(label: item.label, value: item.value, icon: item.icon),
                ],
              ),
              const SizedBox(height: 20),
              const ReportActivityCard(kind: ReportKind.department, reportRoute: AppRoutes.departmentReports),
            ],
          ),
        );
      },
    );
  }
}
