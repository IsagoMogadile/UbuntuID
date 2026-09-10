import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/citizen_repository.dart';

/// Appeals lodged on this citizen's behalf at a department -- read-only:
/// citizens don't lodge these themselves (they visit in person and an
/// official records it), same "citizens do not directly perform
/// departmental CRUD" principle as everything else in this app.
class MyAppealsScreen extends ConsumerWidget {
  const MyAppealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appealsAsync = ref.watch(myAppealsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Appeals')),
      body: appealsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load your appeals.',
          onRetry: () => ref.invalidate(myAppealsProvider),
        ),
        data: (appeals) {
          if (appeals.isEmpty) {
            return const EmptyState(
              icon: Icons.gavel_outlined,
              title: 'No appeals on file',
              message: 'If you dispute a department decision, visit that department in person to lodge an appeal.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: appeals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final appeal = appeals[i];
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(appeal.departmentName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        StatusBadge.fromStatus(appeal.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DetailRow(label: 'Reason', value: appeal.appealReason),
                    DetailRow(label: 'Submitted', value: AppFormatters.date(appeal.submittedAt)),
                    if (appeal.decision != null) DetailRow(label: 'Decision', value: appeal.decision!),
                    if (appeal.decisionNotes != null && appeal.decisionNotes!.isNotEmpty)
                      DetailRow(label: 'Notes', value: appeal.decisionNotes!),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
