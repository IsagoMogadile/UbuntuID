import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/pdf_text.dart';
import '../domain/report_data.dart';

/// Lays a [ReportData] out as a printable A4 report that mirrors the
/// on-screen Reports page: title block (what, who, period), headline numbers
/// as stat boxes, trends as column charts, breakdowns as labelled bars with
/// percentages, tables, then the "About this report" notes. Same data object
/// as the screen, so the PDF and the page always agree.
class ReportPdf {
  ReportPdf._();

  static const _green = PdfColor.fromInt(0xFF00723F);
  static const _greenDark = PdfColor.fromInt(0xFF00512C);
  static const _gold = PdfColor.fromInt(0xFFC9962C);
  static const _ink = PdfColor.fromInt(0xFF1B1F1D);
  static const _muted = PdfColor.fromInt(0xFF54615B);
  static const _border = PdfColor.fromInt(0xFFDCE1DD);
  static const _track = PdfColor.fromInt(0xFFEFF2EF);

  static pw.Widget _text(String text, {pw.TextStyle? style, pw.TextAlign? align, int? maxLines}) =>
      pw.Text(pdfSafe(text), style: style, textAlign: align, maxLines: maxLines);

  static Future<Uint8List> build(ReportData data, {DateTime? generatedAt}) {
    final generated = generatedAt ?? DateTime.now();
    final doc = pw.Document(title: 'UbuntuID - ${data.kind.title}', author: 'UbuntuID prototype');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
        header: (context) => context.pageNumber == 1 ? pw.SizedBox() : _runningHeader(data),
        footer: (context) => _footer(context, generated),
        build: (context) => [
          _titleBlock(data, generated),
          for (final group in data.metricGroups) _keepTogether([_sectionTitle(group.title), _statBoxes(group.metrics)]),
          for (final section in data.sections) ..._section(section),
          if (data.notes.isNotEmpty) ...[
            _sectionTitle('About this report'),
            for (final note in data.notes)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _text('-  ', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
                    pw.Expanded(child: _text(note, style: const pw.TextStyle(fontSize: 8.5, color: _muted))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  /// Up to this many rows, a table is kept on one page with its heading;
  /// longer tables flow across pages (repeating their header row).
  static const _keepTogetherRows = 15;

  /// Moved to the next page whole rather than split, so a heading never
  /// ends up stranded at the bottom of a page away from its content.
  static pw.Widget _keepTogether(List<pw.Widget> children) => pw.Inseparable(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: children),
      );

  static List<pw.Widget> _section(ReportSection section) {
    final heading = [
      _sectionTitle(section.title),
      if (section.description != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: _text(section.description!, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
        ),
    ];
    return switch (section) {
      TrendSection(:final points) => [_keepTogether([...heading, _trendChart(points)])],
      BreakdownSection(:final items) => [_keepTogether([...heading, _breakdown(items)])],
      TableSection(:final rows) when rows.length <= _keepTogetherRows => [_keepTogether([...heading, _table(section)])],
      // A long table keeps its heading with the first rows, then flows on.
      TableSection(:final headers, :final rows, :final emptyMessage) => [
          _keepTogether([
            ...heading,
            _table(TableSection(title: section.title, headers: headers, rows: rows.sublist(0, _keepTogetherRows))),
          ]),
          _table(TableSection(
            title: section.title,
            headers: headers,
            rows: rows.sublist(_keepTogetherRows),
            emptyMessage: emptyMessage,
          )),
        ],
    };
  }

  // -- Page furniture ------------------------------------------------------

  static pw.Widget _mark({double size = 34}) => pw.Container(
        width: size,
        height: size,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: _green,
          borderRadius: pw.BorderRadius.circular(size * 0.2),
          border: pw.Border.all(color: _gold, width: 1.5),
        ),
        child: _text('U', style: pw.TextStyle(fontSize: size * 0.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      );

  static pw.Widget _titleBlock(ReportData data, DateTime generated) {
    pw.Widget line(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: pdfSafe('$label: '), style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
              pw.TextSpan(text: pdfSafe(value), style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _gold, width: 2))),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _mark(size: 44),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _text('UBUNTUID',
                    style: pw.TextStyle(fontSize: 8, color: _green, letterSpacing: 1.5, fontWeight: pw.FontWeight.bold)),
                _text(data.kind.title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink)),
                pw.SizedBox(height: 4),
                line(data.ownerLabel, data.ownerName),
                line('Reporting period', data.range.label),
                line('Generated', DateFormat('d MMMM y, HH:mm').format(generated)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _runningHeader(ReportData data) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.5))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _text('${data.kind.title} - ${data.ownerName}', style: const pw.TextStyle(fontSize: 8, color: _muted)),
            _text(data.range.label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
          ],
        ),
      );

  static pw.Widget _footer(pw.Context context, DateTime generated) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        padding: const pw.EdgeInsets.only(top: 4),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _border, width: 0.5))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _text('UbuntuID prototype report - generated from UbuntuID data on ${DateFormat('d MMM y').format(generated)}',
                style: const pw.TextStyle(fontSize: 7, color: _muted)),
            _text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: _muted)),
          ],
        ),
      );

  static pw.Widget _sectionTitle(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
        child: _text(title.toUpperCase(),
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _greenDark, letterSpacing: 0.8)),
      );

  // -- Content -------------------------------------------------------------

  /// Headline numbers as equal-width boxes, up to four per row.
  static pw.Widget _statBoxes(List<ReportMetric> metrics) {
    const perRow = 4;
    final rows = <List<ReportMetric>>[
      for (var i = 0; i < metrics.length; i += perRow) metrics.sublist(i, (i + perRow).clamp(0, metrics.length)),
    ];
    final number = NumberFormat.decimalPattern('en_ZA');
    return pw.Column(
      children: [
        for (final row in rows)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              children: [
                for (var i = 0; i < perRow; i++) ...[
                  if (i > 0) pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: i < row.length
                        ? pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: _border, width: 0.8),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _text(number.format(row[i].value),
                                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _ink)),
                                pw.SizedBox(height: 2),
                                _text(row[i].label, style: const pw.TextStyle(fontSize: 8, color: _muted), maxLines: 2),
                              ],
                            ),
                          )
                        : pw.SizedBox(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// Column chart of counts over time, value above each bar. With many
  /// bars only every few labels are printed so they never overlap.
  static pw.Widget _trendChart(List<(String, int)> points) {
    if (points.every((p) => p.$2 == 0)) return _empty('No activity in this period.');
    const chartHeight = 110.0;
    final maxValue = points.map((p) => p.$2).fold(0, (a, b) => a > b ? a : b);
    final labelEvery = (points.length / 8).ceil().clamp(1, points.length);

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(8, 10, 8, 6),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _border, width: 0.8), borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(
        children: [
          pw.SizedBox(
            height: chartHeight + 12,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                for (final (_, value) in points)
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          if (value > 0) _text('$value', style: const pw.TextStyle(fontSize: 6.5, color: _muted)),
                          pw.SizedBox(height: 1),
                          pw.Container(
                            width: 28,
                            height: maxValue == 0 ? 0 : (value / maxValue) * chartHeight,
                            decoration: const pw.BoxDecoration(
                              color: _green,
                              borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          pw.Container(height: 0.6, color: _border),
          pw.SizedBox(height: 3),
          pw.Row(
            children: [
              for (var i = 0; i < points.length; i++)
                pw.Expanded(
                  child: _text(i % labelEvery == 0 ? points[i].$1 : '',
                      style: const pw.TextStyle(fontSize: 6.5, color: _muted), align: pw.TextAlign.center),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Labelled horizontal bars with count and share -- reads clearly in
  /// print and in black and white, unlike a donut.
  static pw.Widget _breakdown(List<(String, int)> items) {
    if (items.isEmpty || items.every((i) => i.$2 == 0)) return _empty('Nothing to show for this period.');
    final total = items.fold(0, (sum, i) => sum + i.$2);
    final maxValue = items.map((i) => i.$2).fold(0, (a, b) => a > b ? a : b);

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _border, width: 0.8), borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(
        children: [
          for (final (label, value) in items)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 150, child: _text(label, style: const pw.TextStyle(fontSize: 8.5), maxLines: 1)),
                  pw.Expanded(
                    child: pw.Stack(
                      children: [
                        pw.Container(height: 9, color: _track),
                        pw.Row(children: [
                          if (value > 0) pw.Expanded(flex: value, child: pw.Container(height: 9, color: _green)),
                          if (maxValue - value > 0) pw.Expanded(flex: maxValue - value, child: pw.SizedBox(height: 9)),
                        ]),
                      ],
                    ),
                  ),
                  pw.SizedBox(
                    width: 70,
                    child: _text('$value  (${total == 0 ? 0 : (value * 100 / total).round()}%)',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold), align: pw.TextAlign.right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _table(TableSection section) {
    if (section.rows.isEmpty) return _empty(section.emptyMessage);
    return pw.TableHelper.fromTextArray(
      headers: [for (final h in section.headers) pdfSafe(h)],
      data: [
        for (final row in section.rows) [for (final cell in row) pdfSafe(cell)],
      ],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: _ink),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      headerCount: 1,
      // Fixed, even widths so a long table's continuation lines up exactly
      // with its first part.
      columnWidths: {for (var i = 0; i < section.headers.length; i++) i: const pw.FlexColumnWidth()},
      cellAlignment: pw.Alignment.centerLeft,
      border: pw.TableBorder.all(color: _border, width: 0.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    );
  }

  static pw.Widget _empty(String message) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _border, width: 0.8), borderRadius: pw.BorderRadius.circular(4)),
        child: _text(message, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
      );
}
