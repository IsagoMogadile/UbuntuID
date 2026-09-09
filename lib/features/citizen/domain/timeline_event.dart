import 'package:flutter/material.dart';

/// One entry on the citizen's life-events timeline
/// (`CitizenTimelineScreen`) -- aggregated from several tables
/// (`citizens.registered_at`, `credentials`, `dha_marital_records`), not
/// its own table.
class TimelineEvent {
  const TimelineEvent({
    required this.date,
    required this.title,
    required this.icon,
    this.subtitle,
  });

  final DateTime date;
  final String title;
  final IconData icon;
  final String? subtitle;
}
