import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Bar chart of counts over time. Colours come from the active
/// `ColorScheme`, so it stays on UbuntuID's own green/gold identity in light
/// and dark mode. With many bars only every few labels are drawn, so the
/// axis never turns into an unreadable smear.
class TrendBarChart extends StatelessWidget {
  const TrendBarChart({super.key, required this.data, this.height = 200});

  final List<(String, int)> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (data.every((e) => e.$2 == 0)) {
      return SizedBox(height: height / 2, child: const Center(child: Text('No activity in this period.')));
    }
    final maxValue = data.map((e) => e.$2).fold(0, (a, b) => a > b ? a : b);
    final maxY = (maxValue + (maxValue / 5).ceil().clamp(1, 1 << 30)).toDouble();
    final labelEvery = (data.length / 8).ceil().clamp(1, data.length);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = (constraints.maxWidth / data.length * 0.55).clamp(4.0, 22.0);
          return BarChart(
            BarChartData(
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY / 4).clamp(1, double.infinity),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    '${data[group.x].$1}\n${rod.toY.toInt()}',
                    TextStyle(color: scheme.onInverseSurface, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: (maxY / 4).clamp(1, double.infinity),
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= data.length || i % labelEvery != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(data[i].$1, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
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
                        width: barWidth,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A small donut plus a legend with exact counts and percentages -- for a
/// short, fixed set of statuses.
class StatusDonut extends StatelessWidget {
  const StatusDonut({super.key, required this.data, this.emptyMessage = 'Nothing to show for this period.'});

  final List<(String, int)> data;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [scheme.primary, scheme.secondary, scheme.tertiary, scheme.error, scheme.outline, scheme.inversePrimary];
    final total = data.fold(0, (sum, e) => sum + e.$2);
    if (total == 0) {
      return SizedBox(height: 80, child: Center(child: Text(emptyMessage)));
    }

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          height: 150,
          width: 150,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              sections: [
                for (var i = 0; i < data.length; i++)
                  PieChartSectionData(
                    value: data[i].$2.toDouble(),
                    color: palette[i % palette.length],
                    showTitle: false,
                    radius: 28,
                  ),
              ],
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < data.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: palette[i % palette.length], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: Text(data[i].$1, style: const TextStyle(fontSize: 13))),
                      const SizedBox(width: 8),
                      Text(
                        '${data[i].$2} (${(data[i].$2 * 100 / total).round()}%)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
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
