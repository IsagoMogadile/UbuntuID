import 'dart:io';

import 'package:digital_id/features/reports/domain/report_data.dart';
import 'package:digital_id/features/reports/domain/report_range.dart';
import 'package:digital_id/features/reports/presentation/report_pdf.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

/// Builds report PDFs from sample data. Set UBUNTUID_PDF_OUT to a folder to
/// also write them there for visual review.
void main() {
  final range = ReportRange.preset(ReportPreset.last6Months, now: DateTime(2026, 9, 30));
  final outDir = Platform.environment['UBUNTUID_PDF_OUT'];

  ReportData sample({int historyRows = 6}) => ReportData(
        kind: ReportKind.department,
        ownerLabel: 'Department',
        ownerName: 'Department of Transport',
        range: range,
        metricGroups: const [
          ReportMetricGroup(title: 'Department (current)', metrics: [
            ReportMetric(label: 'Active officials', value: 12, icon: Icons.groups_outlined),
            ReportMetric(label: 'Records on file', value: 1240, icon: Icons.folder_open_outlined),
          ]),
          ReportMetricGroup(title: 'Activity in this period', metrics: [
            ReportMetric(label: 'Credentials issued', value: 87, icon: Icons.badge_outlined),
            ReportMetric(label: 'Citizens served', value: 80, icon: Icons.person_outline),
            ReportMetric(label: 'Completed', value: 70, icon: Icons.task_alt_outlined),
            ReportMetric(label: 'In progress', value: 12, icon: Icons.hourglass_top_outlined),
            ReportMetric(label: 'Rejected or failed', value: 5, icon: Icons.cancel_outlined),
          ]),
        ],
        sections: [
          TrendSection(title: 'Credentials issued over time', points: range.trend([
            for (var i = 0; i < 87; i++) DateTime(2026, 4 + i % 6, 1 + i % 27),
          ])),
          const BreakdownSection(
            title: 'Status of credentials issued',
            description: "Expired is worked out from each credential's expiry date.",
            items: [('Active', 70), ('Expired', 12), ('Suspended', 5)],
            asDonut: true,
          ),
          const BreakdownSection(
            title: 'Records by service (all time)',
            items: [("Driver's Licence", 900), ('Vehicle / Number Plate', 340)],
          ),
          TableSection(
            title: 'Recent activity',
            headers: const ['Date', 'Reference', 'Credentials', 'Status'],
            rows: [
              for (var i = 0; i < historyRows; i++) ['${i + 1} Sep 2026', 'AB12CD${i}0', '2', 'Completed'],
            ],
          ),
          const TrendSection(title: 'Nothing here', points: [('Apr 26', 0), ('May 26', 0)]),
        ],
        notes: const [
          'Departments do not receive verification requests - verification is automated.',
          '"Records by service" is all-time.',
        ],
      );

  test('builds a one-page report', () async {
    final bytes = await ReportPdf.build(sample(), generatedAt: DateTime(2026, 9, 30, 14, 5));
    expect(bytes.length, greaterThan(1000));
    if (outDir != null) await File('$outDir/report_department.pdf').writeAsBytes(bytes);
  });

  test('long tables flow onto further pages', () async {
    final bytes = await ReportPdf.build(sample(historyRows: 120), generatedAt: DateTime(2026, 9, 30, 14, 5));
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length, greaterThan(1));
    if (outDir != null) await File('$outDir/report_long.pdf').writeAsBytes(bytes);
  });
}
