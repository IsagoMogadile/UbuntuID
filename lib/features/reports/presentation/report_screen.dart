import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/report_export.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/horizontal_bar_list.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/overview_strip.dart';
import '../../../core/widgets/section_header.dart';
import '../data/reports_repository.dart';
import '../domain/report_data.dart';
import '../domain/report_range.dart';
import 'report_charts.dart';
import 'report_pdf.dart';

/// The Reports tab for every role -- one layout, so all four reports read
/// the same way: what it is, who it belongs to, the period, headline
/// numbers, then trends and breakdowns, then notes on what it can't show.
/// The [kind] decides which (RLS-scoped) data is loaded.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.kind});

  final ReportKind kind;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  ReportRange _range = ReportRange.preset(ReportPreset.last30Days);

  (ReportKind, ReportRange) get _key => (widget.kind, _range);

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _range.start, end: _range.end),
      helpText: 'Reporting period',
    );
    if (picked != null) setState(() => _range = ReportRange.custom(picked.start, picked.end));
  }

  Future<void> _download(ReportData data, {required bool pdf}) async {
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    final base = 'ubuntuid_${data.kind.name}_report_$stamp';
    try {
      if (pdf) {
        await Printing.sharePdf(bytes: await ReportPdf.build(data), filename: '$base.pdf');
      } else {
        await ReportExport.exportCsv(
          filename: '$base.csv',
          headers: const ['Section', 'Item', 'Value'],
          rows: data.toExportRows(),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not download the report.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportProvider(_key));
    final data = reportAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh data',
            onPressed: () => ref.invalidate(reportProvider(_key)),
          ),
          PopupMenuButton<bool>(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Download report',
            enabled: data != null,
            onSelected: (pdf) => _download(data!, pdf: pdf),
            itemBuilder: (context) => const [
              PopupMenuItem(value: true, child: Text('Download PDF')),
              PopupMenuItem(value: false, child: Text('Download CSV')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(reportProvider(_key).future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PeriodSelector(
                      range: _range,
                      onPreset: (preset) => setState(() => _range = ReportRange.preset(preset)),
                      onCustom: _pickCustomRange,
                    ),
                    const SizedBox(height: 16),
                    reportAsync.when(
                      skipLoadingOnRefresh: false,
                      loading: () => const SizedBox(height: 240, child: LoadingIndicator(message: 'Building report...')),
                      error: (error, _) => ErrorView(
                        title: 'Report unavailable',
                        message: error is AppException ? error.message : 'Could not load this report.',
                        onRetry: () => ref.invalidate(reportProvider(_key)),
                      ),
                      data: (data) => _ReportBody(
                        data: data,
                        onDownloadPdf: () => _download(data, pdf: true),
                        onDownloadCsv: () => _download(data, pdf: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.range, required this.onPreset, required this.onCustom});

  final ReportRange range;
  final ValueChanged<ReportPreset> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in ReportPreset.values)
          ChoiceChip(
            label: Text(preset.label),
            selected: range.preset == preset,
            avatar: preset == ReportPreset.custom ? const Icon(Icons.date_range_outlined, size: 18) : null,
            onSelected: (_) => preset == ReportPreset.custom ? onCustom() : onPreset(preset),
          ),
      ],
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.data, required this.onDownloadPdf, required this.onDownloadCsv});

  final ReportData data;
  final VoidCallback onDownloadPdf;
  final VoidCallback onDownloadCsv;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.kind.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              _HeaderLine(label: data.ownerLabel, value: data.ownerName),
              _HeaderLine(label: 'Reporting period', value: data.range.label),
              _HeaderLine(label: 'Generated', value: DateFormat('d MMMM y, HH:mm').format(DateTime.now())),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onDownloadPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Download PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDownloadCsv,
                    icon: const Icon(Icons.table_chart_outlined, size: 18),
                    label: const Text('Download CSV'),
                  ),
                ],
              ),
            ],
          ),
        ),
        for (final group in data.metricGroups) ...[
          const SizedBox(height: 20),
          SectionHeader(title: group.title),
          OverviewStrip(
            items: [for (final m in group.metrics) OverviewItem(label: m.label, value: m.value, icon: m.icon)],
          ),
        ],
        for (final section in data.sections) ...[
          const SizedBox(height: 20),
          SectionHeader(title: section.title),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (section.description != null) ...[
                  Text(section.description!, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                ],
                switch (section) {
                  TrendSection(:final points) => TrendBarChart(data: points),
                  BreakdownSection(:final items, asDonut: true) => StatusDonut(data: items),
                  BreakdownSection(:final items) => HorizontalBarList(data: items, labelWidth: 160),
                  TableSection() => _ReportTable(section: section),
                },
              ],
            ),
          ),
        ],
        if (data.notes.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader(title: 'About this report'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final note in data.notes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(child: Text(note, style: theme.textTheme.bodySmall)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _HeaderLine extends StatelessWidget {
  const _HeaderLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.section});

  final TableSection section;

  @override
  Widget build(BuildContext context) {
    if (section.rows.isEmpty) {
      return SizedBox(height: 60, child: Center(child: Text(section.emptyMessage)));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 56,
        horizontalMargin: 4,
        columnSpacing: 24,
        columns: [for (final h in section.headers) DataColumn(label: Text(h))],
        rows: [
          for (final row in section.rows) DataRow(cells: [for (final cell in row) DataCell(Text(cell))]),
        ],
      ),
    );
  }
}
