import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/citizen_repository.dart';
import '../documents/document_downloads.dart';
import '../domain/nsc_statement.dart';

/// A citizen's published National Senior Certificate Statement of Results,
/// opened from the "Statement of Results" option on the matching
/// certificate card (Government Services → Basic Education → National
/// Senior Certificate).
class NscStatementScreen extends ConsumerWidget {
  const NscStatementScreen({super.key, required this.matricExamNumber});

  final String matricExamNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statementsAsync = ref.watch(myNscStatementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Statement of Results')),
      body: statementsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Your Statement of Results could not be loaded. Check your connection and try again.',
          onRetry: () => ref.invalidate(myNscStatementsProvider),
        ),
        data: (statements) {
          final matches = statements.where((s) => s.matricExamNumber == matricExamNumber);
          if (matches.isEmpty) {
            return const EmptyState(
              icon: Icons.description_outlined,
              title: 'Not yet available',
              message: 'Your Statement of Results is not yet available.',
            );
          }
          return _StatementView(statement: matches.first);
        },
      ),
    );
  }
}

class _StatementView extends ConsumerWidget {
  const _StatementView({required this.statement});

  final NscStatement statement;

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final identity = await ref.read(digitalIdentityProvider.future);
    if (!context.mounted) return;
    await DocumentDownloads.nscStatement(context, ref, identity, statement);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? Colors.white70 : AppColors.charcoalMuted;

    // Full-width scroll view (scrollbar at the window's edge) with the
    // document centred inside it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(16.0, (constraints.maxWidth - 760) / 2);
        return ListView(
          padding: EdgeInsets.fromLTRB(side, 16, side, 32),
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(statement: statement),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionTitle('Learner information'),
                        _InfoGrid(items: [
                          ('Full name', statement.learnerName.isEmpty ? '—' : statement.learnerName),
                          ('Examination number', statement.examNumber),
                          ('Examination year', '${statement.examYear}'),
                          if (statement.schoolName != null) ('School', statement.schoolName!),
                          if (statement.examSession != null) ('Examination session', statement.examSession!),
                        ]),
                        const SizedBox(height: 20),
                        _SectionTitle('Examination results'),
                        _ResultsTable(subjects: statement.subjects),
                        const SizedBox(height: 18),
                        _OverallResult(statement: statement),
                        const SizedBox(height: 16),
                        _InfoGrid(items: [
                          ('Examination year', '${statement.examYear}'),
                          if (statement.publishedAt != null) ('Published', AppFormatters.date(statement.publishedAt!)),
                          ('Record reference', statement.recordReference),
                        ]),
                        const SizedBox(height: 14),
                        Text(
                          'Achievement levels: 7 (80–100%), 6 (70–79%), 5 (60–69%), 4 (50–59%), 3 (40–49%), '
                          '2 (30–39%), 1 (0–29%). Results are provided by the Department of Basic Education and '
                          'shown here by UbuntuID; this is not a certified National Senior Certificate.',
                          style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Download Statement',
              icon: Icons.download_outlined,
              expand: true,
              onPressed: () => _download(context, ref),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.statement});

  final NscStatement statement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.greenDark, AppColors.green]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppLogo(size: 28, onDark: true),
          const SizedBox(height: 14),
          const Text(
            'DEPARTMENT OF BASIC EDUCATION',
            style: TextStyle(color: AppColors.goldLight, fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'National Senior Certificate',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'Statement of Results · ${statement.examYear}',
            style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 2, width: 36, color: AppColors.gold),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white70 : AppColors.charcoalMuted;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 480 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            for (final (label, value) in items)
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 12, color: muted)),
                    const SizedBox(height: 2),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ResultsTable extends StatelessWidget {
  const _ResultsTable({required this.subjects});

  final List<NscSubjectResult> subjects;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.borderDark : AppColors.border;
    final headerFill = isDark ? AppColors.surfaceMutedDark : AppColors.surfaceMuted;
    const headerStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 13);

    Widget cell(Widget child, {Alignment align = Alignment.centerLeft}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Align(alignment: align, child: child),
        );

    return Container(
      decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {0: FlexColumnWidth(5), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2.2)},
        border: TableBorder(horizontalInside: BorderSide(color: border)),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: headerFill),
            children: [
              cell(const Text('Subject', style: headerStyle)),
              cell(const Text('Percentage', style: headerStyle), align: Alignment.center),
              cell(const Text('Achievement level', style: headerStyle, textAlign: TextAlign.center),
                  align: Alignment.center),
            ],
          ),
          for (final s in subjects)
            TableRow(
              children: [
                cell(Text(s.subject)),
                cell(Text(s.percentageLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    align: Alignment.center),
                cell(_LevelChip(level: s.achievementLevel), align: Alignment.center),
              ],
            ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final int? level;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: primary.withValues(alpha: 0.12)),
      child: Text(
        level?.toString() ?? '—',
        style: TextStyle(fontWeight: FontWeight.w800, color: primary),
      ),
    );
  }
}

class _OverallResult extends StatelessWidget {
  const _OverallResult({required this.statement});

  final NscStatement statement;

  @override
  Widget build(BuildContext context) {
    final colour = statement.achieved ? AppColors.success : AppColors.error;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: isDark ? 0.18 : 0.08),
        border: Border.all(color: colour.withValues(alpha: 0.6), width: 1.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(statement.achieved ? Icons.workspace_premium_outlined : Icons.info_outline,
              color: isDark ? Color.lerp(colour, Colors.white, 0.5) : colour, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OVERALL RESULT', style: TextStyle(fontSize: 11.5, letterSpacing: 1, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  statement.passCategory,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Color.lerp(colour, Colors.white, 0.5) : colour,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
