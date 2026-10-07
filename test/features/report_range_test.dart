import 'package:digital_id/core/utils/credential_status.dart';
import 'package:digital_id/features/reports/domain/report_data.dart';
import 'package:digital_id/features/reports/domain/report_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 30, 15, 45);

  group('ReportRange.preset', () {
    test('last 7 days covers today and the 6 days before, as whole days', () {
      final range = ReportRange.preset(ReportPreset.last7Days, now: now);
      expect(range.start, DateTime(2026, 9, 24));
      expect(range.end, DateTime(2026, 9, 30));
      expect(range.dayCount, 7);
      expect(range.startDate, '2026-09-24');
      expect(range.endDate, '2026-09-30');
    });

    test('last 6 months starts on the first of the month 5 months back', () {
      final range = ReportRange.preset(ReportPreset.last6Months, now: now);
      expect(range.start, DateTime(2026, 4, 1));
    });

    test('contains is inclusive of the whole last day', () {
      final range = ReportRange.preset(ReportPreset.last7Days, now: now);
      expect(range.contains(DateTime(2026, 9, 30, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 10, 1)), isFalse);
      expect(range.contains(DateTime(2026, 9, 23, 23, 59)), isFalse);
      expect(range.contains(null), isFalse);
    });

    test('ranges with the same preset and days are equal (provider cache key)', () {
      expect(ReportRange.preset(ReportPreset.last30Days, now: now),
          ReportRange.preset(ReportPreset.last30Days, now: now.add(const Duration(hours: 2))));
    });
  });

  group('ReportRange.buckets', () {
    test('daily for a week', () {
      final range = ReportRange.preset(ReportPreset.last7Days, now: now);
      expect(range.buckets(), hasLength(7));
    });

    test('weekly for 30 days, last bucket clipped to the range', () {
      final range = ReportRange.preset(ReportPreset.last30Days, now: now);
      final buckets = range.buckets();
      expect(buckets, hasLength(5));
      expect(buckets.last.endExclusive, range.endExclusive);
    });

    test('monthly for 6 months', () {
      final range = ReportRange.preset(ReportPreset.last6Months, now: now);
      expect(range.buckets().map((b) => b.label), ['Apr 26', 'May 26', 'Jun 26', 'Jul 26', 'Aug 26', 'Sep 26']);
    });
  });

  test('trend counts only dates inside the range', () {
    final range = ReportRange.preset(ReportPreset.last7Days, now: now);
    final points = range.trend([
      DateTime(2026, 9, 24, 8),
      DateTime(2026, 9, 24, 20),
      DateTime(2026, 9, 30, 23),
      DateTime(2026, 9, 1), // before the range
      null,
    ]);
    expect(points.first.$2, 2);
    expect(points.last.$2, 1);
    expect(points.fold(0, (sum, p) => sum + p.$2), 3);
  });

  test('humaniseStatus', () {
    expect(humaniseStatus('partially_verified'), 'Partially verified');
    expect(humaniseStatus('exact_match'), 'Exact match');
    expect(humaniseStatus(''), 'Unknown');
  });

  test('effectiveCredentialStatus treats a past-expiry active credential as expired', () {
    expect(effectiveCredentialStatus('active', DateTime(2000)), 'expired');
    expect(effectiveCredentialStatus('active', null), 'active');
    expect(effectiveCredentialStatus('revoked', DateTime(2000)), 'revoked');
    expect(effectiveCredentialStatus(null, null), 'pending');
  });
}
