import 'package:intl/intl.dart';

enum ReportPreset {
  last7Days('Last 7 days'),
  last30Days('Last 30 days'),
  last6Months('Last 6 months'),
  lastYear('Last year'),
  custom('Custom range');

  const ReportPreset(this.label);

  final String label;
}

/// One bar of a report's trend chart: [label] covers `[start, endExclusive)`.
class ReportBucket {
  const ReportBucket({required this.label, required this.start, required this.endExclusive});

  final String label;
  final DateTime start;
  final DateTime endExclusive;

  bool contains(DateTime value) => !value.isBefore(start) && value.isBefore(endExclusive);
}

/// The reporting period a report is filtered to -- whole local days, [start]
/// through [end] inclusive. Every dated query in `ReportsRepository` is
/// bounded by it, so changing the period really changes the numbers.
class ReportRange {
  ReportRange._(this.preset, DateTime start, DateTime end)
      : start = DateTime(start.year, start.month, start.day),
        end = DateTime(end.year, end.month, end.day);

  factory ReportRange.preset(ReportPreset preset, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final start = switch (preset) {
      ReportPreset.last7Days => today.subtract(const Duration(days: 6)),
      ReportPreset.last30Days => today.subtract(const Duration(days: 29)),
      ReportPreset.last6Months => DateTime(today.year, today.month - 5, 1),
      ReportPreset.lastYear => DateTime(today.year, today.month - 11, 1),
      ReportPreset.custom => today.subtract(const Duration(days: 29)),
    };
    return ReportRange._(preset, start, today);
  }

  factory ReportRange.custom(DateTime start, DateTime end) => ReportRange._(ReportPreset.custom, start, end);

  final ReportPreset preset;
  final DateTime start;
  final DateTime end;

  DateTime get endExclusive => DateTime(end.year, end.month, end.day + 1);

  /// For `timestamptz` columns (`requested_at`, `registered_at`, ...).
  String get startTimestamp => start.toUtc().toIso8601String();
  String get endExclusiveTimestamp => endExclusive.toUtc().toIso8601String();

  /// For plain `date` columns (`credentials.issued_date`).
  String get startDate => _isoDate.format(start);
  String get endDate => _isoDate.format(end);

  bool contains(DateTime? value) => value != null && !value.isBefore(start) && value.isBefore(endExclusive);

  static final _isoDate = DateFormat('yyyy-MM-dd');
  static final _display = DateFormat('d MMMM y');

  /// e.g. "1 September 2026 – 30 September 2026".
  String get label => '${_display.format(start)} – ${_display.format(end)}';

  int get dayCount => endExclusive.difference(start).inDays;

  /// Daily bars for up to two weeks, weekly up to ~3 months, monthly beyond.
  List<ReportBucket> buckets() {
    final buckets = <ReportBucket>[];
    if (dayCount <= 14) {
      for (var d = start; d.isBefore(endExclusive); d = DateTime(d.year, d.month, d.day + 1)) {
        buckets.add(ReportBucket(
          label: DateFormat('d MMM').format(d),
          start: d,
          endExclusive: DateTime(d.year, d.month, d.day + 1),
        ));
      }
    } else if (dayCount <= 92) {
      for (var d = start; d.isBefore(endExclusive); d = DateTime(d.year, d.month, d.day + 7)) {
        final next = DateTime(d.year, d.month, d.day + 7);
        buckets.add(ReportBucket(
          label: DateFormat('d MMM').format(d),
          start: d,
          endExclusive: next.isAfter(endExclusive) ? endExclusive : next,
        ));
      }
    } else {
      for (var d = DateTime(start.year, start.month, 1); d.isBefore(endExclusive); d = DateTime(d.year, d.month + 1, 1)) {
        final bucketStart = d.isBefore(start) ? start : d;
        final next = DateTime(d.year, d.month + 1, 1);
        buckets.add(ReportBucket(
          label: DateFormat('MMM yy').format(d),
          start: bucketStart,
          endExclusive: next.isAfter(endExclusive) ? endExclusive : next,
        ));
      }
    }
    return buckets;
  }

  /// Counts [dates] into [buckets] -- dates outside the range are ignored.
  List<(String, int)> trend(Iterable<DateTime?> dates) {
    final bucketList = buckets();
    final counts = List<int>.filled(bucketList.length, 0);
    for (final date in dates) {
      if (date == null) continue;
      final i = bucketList.indexWhere((b) => b.contains(date));
      if (i >= 0) counts[i]++;
    }
    return [for (var i = 0; i < bucketList.length; i++) (bucketList[i].label, counts[i])];
  }

  @override
  bool operator ==(Object other) =>
      other is ReportRange && other.preset == preset && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(preset, start, end);
}
