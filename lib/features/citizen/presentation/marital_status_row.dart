import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/detail_row.dart';
import '../data/citizen_repository.dart';

/// "Marital status: Married to Thandi Mokoena (since 14 Feb 2024)", from the
/// citizen's Home Affairs marriage records.
class MaritalStatusRow extends ConsumerWidget {
  const MaritalStatusRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marriagesAsync = ref.watch(myMarriagesProvider);
    final value = marriagesAsync.when(
      loading: () => 'Loading…',
      error: (_, _) => 'Not available',
      data: (marriages) {
        if (marriages.isEmpty) return 'No marriage on record';
        final latest = marriages.first;
        final since = DateTime.tryParse(latest['date_of_marriage']?.toString() ?? '');
        return since == null ? spouseLabel(latest) : '${spouseLabel(latest)} (since ${AppFormatters.date(since)})';
      },
    );
    return DetailRow(label: 'Marital status', value: value);
  }
}
