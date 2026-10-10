import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../data/exam_results_repository.dart';
import 'exam_results_screen.dart';

/// One synchronised examination record: its marks and calculated
/// achievement levels, the calculated and official pass categories, why it
/// needs review (if it does), and its publication. View-only -- marks and
/// categories can only change through the results source.
class ExamResultDetailScreen extends ConsumerStatefulWidget {
  const ExamResultDetailScreen({super.key, required this.statementId});

  final String statementId;

  @override
  ConsumerState<ExamResultDetailScreen> createState() => _ExamResultDetailScreenState();
}

class _ExamResultDetailScreenState extends ConsumerState<ExamResultDetailScreen> {
  bool _busy = false;

  void _refresh() {
    ref.invalidate(examResultDetailProvider(widget.statementId));
    ref.invalidate(examResultsProvider);
    ref.invalidate(examResultsSummaryProvider);
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) AppToast.error(context, failure, error: e);
    } finally {
      if (mounted) setState(() => _busy = false);
      _refresh();
    }
  }

  Future<void> _publish(ExamResultRecord record) => _run(() async {
        final (published, _) =
            await ref.read(examResultsRepositoryProvider).publish(statementIds: [record.statementId]);
        if (!mounted) return;
        if (published == 1) {
          AppToast.success(context, 'Results published', detail: '${record.learnerName} has been notified.');
        } else {
          AppToast.warning(context, 'This record did not meet the publication checks.');
        }
      }, 'The results could not be published.');

  Future<void> _confirmReview(ExamResultRecord record) => _run(() async {
        await ref.read(examResultsRepositoryProvider).confirmReview(record.statementId);
        if (mounted) AppToast.success(context, 'Review recorded');
      }, 'The review could not be recorded.');

  @override
  Widget build(BuildContext context) {
    final recordAsync = ref.watch(examResultDetailProvider(widget.statementId));

    return Scaffold(
      appBar: AppBar(title: const Text('Examination Record')),
      body: recordAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(message: 'This examination record could not be loaded.', onRetry: _refresh),
        data: (record) {
          if (record == null) {
            return const EmptyState(
              icon: Icons.search_off_outlined,
              title: 'Examination record not found',
              message: 'This record may have been removed from the examination results source.',
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final side = math.max(16.0, (constraints.maxWidth - 820) / 2);
              return ListView(
                padding: EdgeInsets.fromLTRB(side, 16, side, 32),
                children: _content(context, record),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _content(BuildContext context, ExamResultRecord record) {
    final theme = Theme.of(context);
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(record.learnerName, style: theme.textTheme.titleLarge)),
                PublicationStatusBadge(status: record.status),
              ],
            ),
            const SizedBox(height: 12),
            DetailRow(label: 'Examination number', value: record.examNumber),
            DetailRow(label: 'Examination year', value: '${record.examYear}'),
            if (record.examSession != null) DetailRow(label: 'Session', value: record.examSession!),
            if (record.schoolName != null) DetailRow(label: 'School', value: record.schoolName!),
            DetailRow(label: 'Citizen match', value: record.citizenMatched ? 'Matched by identity number' : 'Not matched'),
            DetailRow(label: 'Record reference', value: record.recordReference),
            if (record.lastSyncedAt != null)
              DetailRow(label: 'Last synchronised', value: AppFormatters.dateTime(record.lastSyncedAt!)),
            if (record.publishedAt != null) DetailRow(label: 'Published', value: AppFormatters.dateTime(record.publishedAt!)),
          ],
        ),
      ),
      if (record.reviewReasons.isNotEmpty) ...[
        const SizedBox(height: 16),
        _ReviewPanel(record: record),
      ],
      const SizedBox(height: 20),
      const SectionHeader(title: 'Pass category'),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailRow(label: 'Calculated (provisional)', value: record.calculatedPassCategory ?? 'Requires review'),
            DetailRow(label: 'Official outcome', value: record.officialPassCategory ?? 'Not supplied'),
            if (record.checks.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final check in record.checks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        check.met ? Icons.check_circle_outline : Icons.cancel_outlined,
                        size: 18,
                        color: check.met ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(check.requirement)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      const SectionHeader(title: 'Subjects and achievement levels'),
      AppCard(
        padding: EdgeInsets.zero,
        child: record.subjects.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No subject results were supplied for this record.'),
              )
            : Column(
                children: [
                  for (var i = 0; i < record.subjects.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(record.subjects[i].subject),
                      trailing: Text(
                        '${record.subjects[i].percentage == null ? '—' : '${record.subjects[i].percentage!.round()}%'}'
                        '   Level ${record.subjects[i].level ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 10),
      Text(
        'Marks and pass categories come from the examination results source and cannot be edited in UbuntuID. '
        'Corrections must be made at the source and synchronised again.',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 20),
      if (record.changedAfterPublication)
        AppButton(
          label: 'Confirm Review',
          icon: Icons.fact_check_outlined,
          expand: true,
          loading: _busy,
          onPressed: _busy ? null : () => _confirmReview(record),
        )
      else if (record.readyToPublish)
        AppButton(
          label: 'Publish Results',
          icon: Icons.publish_outlined,
          expand: true,
          loading: _busy,
          onPressed: _busy ? null : () => _publish(record),
        ),
    ];
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({required this.record});

  final ExamResultRecord record;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Color.lerp(AppColors.warning, Colors.white, 0.55)! : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.warning.withValues(alpha: 0.2) : AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_outlined, color: fg),
              const SizedBox(width: 8),
              Text(
                record.hasDiscrepancy ? 'Discrepancy identified' : 'Requires review',
                style: TextStyle(fontWeight: FontWeight.w700, color: fg),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final reason in record.reviewReasons)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $reason', style: TextStyle(color: fg)),
            ),
          if (record.changedAfterPublication) ...[
            const SizedBox(height: 8),
            Text(
              'The citizen still sees the previously published results until the update is reviewed and published.',
              style: TextStyle(color: fg, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}
