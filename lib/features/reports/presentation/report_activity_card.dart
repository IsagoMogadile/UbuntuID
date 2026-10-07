import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../data/reports_repository.dart';
import '../domain/report_data.dart';
import '../domain/report_range.dart';
import 'report_charts.dart';

/// A dashboard's one small activity chart: the first trend from that role's
/// report over the last 6 months, plus "View full report". The numbers come
/// from the same report query, so the dashboard and Reports always agree;
/// the detailed breakdown stays on the Reports tab only.
class ReportActivityCard extends ConsumerWidget {
  const ReportActivityCard({super.key, required this.kind, required this.reportRoute});

  final ReportKind kind;
  final String reportRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportProvider((kind, ReportRange.preset(ReportPreset.last6Months))));
    final trend = reportAsync.value?.sections.whereType<TrendSection>().firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: trend == null ? 'Activity (last 6 months)' : '${trend.title} (last 6 months)',
          action: TextButton(onPressed: () => context.go(reportRoute), child: const Text('View full report')),
        ),
        AppCard(
          child: reportAsync.when(
            loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
            error: (_, _) => const SizedBox(
              height: 60,
              child: Center(child: Text('Activity is unavailable right now.')),
            ),
            data: (_) => trend == null
                ? const SizedBox(height: 60, child: Center(child: Text('No activity to chart yet.')))
                : TrendBarChart(data: trend.points, height: 150),
          ),
        ),
      ],
    );
  }
}
