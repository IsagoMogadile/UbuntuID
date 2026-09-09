import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/department_repository.dart';

/// SAPS-only, department-wide "list of offenders and type of offense" -- a
/// read view over the existing `saps_criminal_records` table (no new table
/// needed; previously only viewable per-searched-citizen).
class SapsOffendersScreen extends ConsumerWidget {
  const SapsOffendersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offendersAsync = ref.watch(offendersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Offenders')),
      body: offendersAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) =>
            ErrorView(message: 'Could not load offenders.\n\n$e', onRetry: () => ref.invalidate(offendersProvider)),
        data: (offenders) => offenders.isEmpty
            ? const EmptyState(
                icon: Icons.gavel_outlined,
                title: 'No offenders on record',
                message: 'Criminal records created from Department Records will appear here.',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: offenders.length,
                itemBuilder: (context, i) {
                  final o = offenders[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  o.fullName.isEmpty ? o.idNumber : o.fullName,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              StatusBadge.fromStatus(o.sentenceStatus),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${o.idNumber} • Case ${o.caseNumber}',
                              style: const TextStyle(color: AppColors.charcoalMuted, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text('Offence: ${o.offenceCode}'),
                          const SizedBox(height: 4),
                          Text('Convicted ${AppFormatters.date(o.convictionDate)}',
                              style: const TextStyle(color: AppColors.charcoalMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
