import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/list_search_field.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/exam_results_repository.dart';

/// Basic Education: synchronise NSC examination results, see which need
/// review, and publish them to citizens.
class ExamResultsScreen extends ConsumerStatefulWidget {
  const ExamResultsScreen({super.key});

  @override
  ConsumerState<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends ConsumerState<ExamResultsScreen> {
  PublicationStatus? _filter;
  String _query = '';
  bool _syncing = false;
  bool _publishing = false;

  void _refresh() {
    ref.invalidate(examResultsSummaryProvider);
    ref.invalidate(examResultsProvider);
  }

  Future<void> _synchronise() async {
    setState(() => _syncing = true);
    try {
      final outcome = await ref.read(examResultsRepositoryProvider).synchronise();
      if (!mounted) return;
      AppToast.success(
        context,
        'Results synchronised',
        detail: '${outcome.received} examination records checked: ${outcome.imported} new, '
            '${outcome.updated} updated, ${outcome.requiringReview} requiring review.',
      );
    } catch (e) {
      if (mounted) AppToast.error(context, 'Synchronisation was unsuccessful.', error: e);
    } finally {
      if (mounted) setState(() => _syncing = false);
      _refresh();
    }
  }

  Future<void> _publishAll(int ready) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish Results'),
        content: Text(
          'Publish $ready examination record${ready == 1 ? '' : 's'} ready for publication? Each learner will be '
          'able to view their Statement of Results and will receive a notification. Records requiring review '
          'are not published.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Publish Results')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _publishing = true);
    try {
      final (published, skipped) = await ref.read(examResultsRepositoryProvider).publish();
      if (!mounted) return;
      AppToast.success(
        context,
        'Results published',
        detail: '$published record${published == 1 ? '' : 's'} published'
            '${skipped > 0 ? '; $skipped did not meet the publication checks' : ''}.',
      );
    } catch (e) {
      if (mounted) AppToast.error(context, 'Results could not be published.', error: e);
    } finally {
      if (mounted) setState(() => _publishing = false);
      _refresh();
    }
  }

  bool _matches(ExamResultRecord r) {
    if (_filter != null && r.status != _filter) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return r.learnerName.toLowerCase().contains(q) || r.examNumber.contains(q) || '${r.examYear}' == q;
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(examResultsSummaryProvider);
    final recordsAsync = ref.watch(examResultsProvider);
    final ready = recordsAsync.value?.where((r) => r.readyToPublish).length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Examination Results')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Full-width list so the scrollbar sits at the window's edge.
            final side = math.max(16.0, (constraints.maxWidth - 960) / 2);
            return ListView(
              padding: EdgeInsets.fromLTRB(side, 16, side, 32),
              children: [
                summaryAsync.when(
                  loading: () => const SizedBox(height: 120, child: LoadingIndicator()),
                  error: (error, _) => ErrorView(
                    message: 'Examination results could not be loaded.',
                    onRetry: _refresh,
                  ),
                  data: (summary) => _SummaryPanel(summary: summary),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    AppButton(
                      label: 'Synchronise Results',
                      icon: Icons.sync,
                      loading: _syncing,
                      onPressed: _syncing || _publishing ? null : _synchronise,
                    ),
                    AppButton(
                      label: ready > 0 ? 'Publish Results ($ready)' : 'Publish Results',
                      icon: Icons.publish_outlined,
                      variant: AppButtonVariant.secondary,
                      loading: _publishing,
                      onPressed: ready == 0 || _syncing || _publishing ? null : () => _publishAll(ready),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Examination Records'),
                ListSearchField(
                  hintText: 'Search by learner name, examination number or year',
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, value) in [
                      ('All Results', null),
                      ('Published', PublicationStatus.published),
                      ('Unpublished', PublicationStatus.unpublished),
                      ('Requires Review', PublicationStatus.requiresReview),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _filter == value,
                        onSelected: (_) => setState(() => _filter = value),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                recordsAsync.when(
                  loading: () => const LoadingIndicator(),
                  error: (error, _) => ErrorView(message: 'Examination records could not be loaded.', onRetry: _refresh),
                  data: (records) {
                    if (records.isEmpty) {
                      return const EmptyState(
                        icon: Icons.school_outlined,
                        title: 'No examination results available',
                        message: 'Select Synchronise Results to retrieve examination results.',
                      );
                    }
                    final shown = records.where(_matches).toList();
                    if (shown.isEmpty) {
                      return const EmptyState(
                        icon: Icons.search_off_outlined,
                        title: 'No matching records',
                        message: 'No examination records match this search and filter.',
                      );
                    }
                    return Column(
                      children: [
                        for (final r in shown)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ListItemCard(
                              leadingIcon: Icons.school_outlined,
                              title: r.learnerName,
                              subtitle: 'Exam ${r.examNumber} · ${r.examYear}\n'
                                  'Calculated: ${r.calculatedPassCategory ?? 'Requires review'} · '
                                  'Official: ${r.officialPassCategory ?? 'Not supplied'}',
                              trailing: PublicationStatusBadge(status: r.status),
                              onTap: () => context.push('${AppRoutes.departmentExamResults}/${r.statementId}'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.summary});

  final ExamResultsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = summary.lastSynchronisedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 700 ? 4 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (label, value, icon) in [
                  ('Examination Records', summary.total, Icons.folder_outlined),
                  ('Results Published', summary.published, Icons.check_circle_outline),
                  ('Unpublished', summary.unpublished, Icons.schedule_outlined),
                  ('Records Requiring Review', summary.requiresReview, Icons.report_outlined),
                ])
                  SizedBox(
                    width: width,
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: theme.colorScheme.primary),
                          const SizedBox(height: 8),
                          Text('$value', style: theme.textTheme.headlineSmall),
                          Text(label, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          last == null
              ? 'Results have not been synchronised yet.'
              : 'Last successful synchronisation: ${AppFormatters.dateTime(last)}',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Unpublished / Published / Requires Review, in the shared badge style.
class PublicationStatusBadge extends StatelessWidget {
  const PublicationStatusBadge({super.key, required this.status});

  final PublicationStatus status;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: status.label,
      tone: switch (status) {
        PublicationStatus.published => AppStatusTone.success,
        PublicationStatus.unpublished => AppStatusTone.info,
        PublicationStatus.requiresReview => AppStatusTone.warning,
      },
    );
  }
}
