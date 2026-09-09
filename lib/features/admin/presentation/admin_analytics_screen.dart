import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../data/admin_repository.dart';

/// Admin-only charts over live platform data. Colours are drawn from the
/// active `ColorScheme` (primary/secondary/tertiary + a couple of muted
/// blends of it) rather than a separate chart palette, so this stays on
/// UbuntuID's own green/gold identity in both light and dark mode instead
/// of introducing new, unrelated colours to a government-facing screen.
class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(adminAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: analyticsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load analytics.',
          onRetry: () => ref.invalidate(adminAnalyticsProvider),
        ),
        data: (analytics) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'Citizen registrations (6 months)'),
            const SizedBox(height: 8),
            AppCard(child: _RegistrationsChart(data: analytics.registrationsByMonth)),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Verification requests by status'),
            const SizedBox(height: 8),
            AppCard(child: _StatusDonut(data: analytics.verificationsByStatus)),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Active officials by department'),
            const SizedBox(height: 8),
            AppCard(child: _HorizontalBars(data: analytics.officialsByDepartment)),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Properties by province'),
            const SizedBox(height: 8),
            AppCard(child: _HorizontalBars(data: analytics.propertiesByProvince)),
          ],
        ),
      ),
    );
  }
}

class _RegistrationsChart extends StatelessWidget {
  const _RegistrationsChart({required this.data});

  final List<(String, int)> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY = (data.map((e) => e.$2).fold(0, (a, b) => a > b ? a : b) + 2).toDouble();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY / 4).clamp(1, double.infinity)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(data[i].$1, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].$2.toDouble(),
                    color: scheme.primary,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusDonut extends StatelessWidget {
  const _StatusDonut({required this.data});

  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [scheme.primary, scheme.secondary, scheme.tertiary, scheme.error, scheme.outline];
    final total = data.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      return const SizedBox(height: 160, child: Center(child: Text('No verification requests yet.')));
    }
    final entries = data.entries.toList();

    return Row(
      children: [
        SizedBox(
          height: 160,
          width: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: palette[i % palette.length],
                    title: '${entries[i].value}',
                    radius: 32,
                    titleStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.surface),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: palette[i % palette.length], shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${entries[i].key} (${entries[i].value})', style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HorizontalBars extends StatelessWidget {
  const _HorizontalBars({required this.data});

  final List<(String, int)> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (data.isEmpty) {
      return const SizedBox(height: 60, child: Center(child: Text('No data yet.')));
    }
    final maxValue = data.map((e) => e.$2).fold(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final (label, value) in data)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxValue == 0 ? 0 : value / maxValue,
                      minHeight: 14,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(scheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 28, child: Text('$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
      ],
    );
  }
}
