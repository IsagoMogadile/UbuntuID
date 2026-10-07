import 'package:flutter/material.dart' show IconData;

import 'report_range.dart';

/// Which role's report to build. Each kind is only ever reachable from that
/// role's own navigation shell (the router's role-area guard), and every
/// query behind it is additionally scoped by RLS -- see `ReportsRepository`.
enum ReportKind {
  system('System Report'),
  organisation('Organisation Activity Report'),
  department('Department Performance Report'),
  citizen('My Activity Report');

  const ReportKind(this.title);

  final String title;
}

class ReportMetric {
  const ReportMetric({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;
}

/// A titled row of headline numbers, e.g. "Platform totals (all time)" or
/// "Activity in this period" -- the title always says which of the two it is,
/// so all-time totals are never mistaken for period figures.
class ReportMetricGroup {
  const ReportMetricGroup({required this.title, required this.metrics});

  final String title;
  final List<ReportMetric> metrics;
}

sealed class ReportSection {
  const ReportSection({required this.title, this.description});

  final String title;
  final String? description;
}

/// Counts over time, one bar per [ReportRange.buckets] entry.
class TrendSection extends ReportSection {
  const TrendSection({required super.title, super.description, required this.points});

  final List<(String, int)> points;
}

/// Counts per category. [asDonut] for a small fixed set of statuses; bars
/// otherwise (longer lists such as organisations or departments).
class BreakdownSection extends ReportSection {
  const BreakdownSection({required super.title, super.description, required this.items, this.asDonut = false});

  final List<(String, int)> items;
  final bool asDonut;
}

class TableSection extends ReportSection {
  const TableSection({
    required super.title,
    super.description,
    required this.headers,
    required this.rows,
    this.emptyMessage = 'Nothing to show for this period.',
  });

  final List<String> headers;
  final List<List<String>> rows;
  final String emptyMessage;
}

class ReportData {
  const ReportData({
    required this.kind,
    required this.ownerLabel,
    required this.ownerName,
    required this.range,
    required this.metricGroups,
    required this.sections,
    this.notes = const [],
  });

  final ReportKind kind;

  /// Who the report belongs to, e.g. ("Department", "Home Affairs").
  final String ownerLabel;
  final String ownerName;
  final ReportRange range;
  final List<ReportMetricGroup> metricGroups;
  final List<ReportSection> sections;

  /// Plain statements of what this report can't show and why -- e.g. a
  /// department has no verification-request data by design. Shown in the
  /// report instead of inventing numbers for it.
  final List<String> notes;

  /// Flat (section, item, value) rows for CSV/PDF download.
  List<List<String>> toExportRows() {
    return [
      ['Report', 'Title', kind.title],
      ['Report', ownerLabel, ownerName],
      ['Report', 'Reporting period', range.label],
      for (final group in metricGroups)
        for (final m in group.metrics) [group.title, m.label, '${m.value}'],
      for (final section in sections)
        ...switch (section) {
          TrendSection(:final points) => [for (final p in points) [section.title, p.$1, '${p.$2}']],
          BreakdownSection(:final items) => [for (final i in items) [section.title, i.$1, '${i.$2}']],
          TableSection(:final headers, :final rows) => [
              for (final row in rows)
                [
                  section.title,
                  row.first,
                  [for (var i = 1; i < row.length; i++) '${headers[i]}: ${row[i]}'].join('; '),
                ],
            ],
        },
      for (final note in notes) ['Note', '', note],
    ];
  }
}

/// "partially_verified" -> "Partially verified".
String humaniseStatus(String raw) {
  final text = raw.replaceAll('_', ' ').trim();
  if (text.isEmpty) return 'Unknown';
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}
