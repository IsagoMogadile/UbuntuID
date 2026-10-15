import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/pdf_branding.dart';
import '../../../core/utils/pdf_text.dart';
import 'guide_topics.dart';

/// The citizen user guide as a printable A4 PDF: a cover, a contents page,
/// then one section per [GuideTopic] with its screen picture beside the
/// numbered steps, ending with a "where is everything" table.
class GuidePdf {
  GuidePdf._();

  static const fileName = 'UbuntuID_Citizen_Guide.pdf';

  static const _green = PdfColor.fromInt(0xFF00723F);
  static const _greenLight = PdfColor.fromInt(0xFFE3F3E9);
  static const _gold = PdfColor.fromInt(0xFFC9962C);
  static const _goldLight = PdfColor.fromInt(0xFFF7ECD6);
  static const _ink = PdfColor.fromInt(0xFF1B1F1D);
  static const _muted = PdfColor.fromInt(0xFF54615B);
  static const _border = PdfColor.fromInt(0xFFDCE1DD);

  static pw.Widget _text(String text, {pw.TextStyle? style, pw.TextAlign? align}) =>
      pw.Text(pdfSafe(text), style: style, textAlign: align);

  static Future<Uint8List> build({List<GuideTopic> topics = citizenGuideTopics, DateTime? generatedAt}) async {
    await PdfBranding.load();
    final generated = generatedAt ?? DateTime.now();
    final doc = pw.Document(title: 'UbuntuID Citizen Guide', author: 'UbuntuID');

    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero, build: (_) => _cover(generated)));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
        header: (context) => _runningHeader(),
        footer: _footer,
        build: (context) => [
          _contents(topics),
          // One topic per page, so a heading never ends up apart from its picture.
          for (final (i, topic) in topics.indexed) ...[pw.NewPage(), _topic(i + 1, topic)],
          pw.NewPage(),
          _quickReference(topics),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _cover(DateTime generated) {
    return pw.Column(
      children: [
        pw.Container(
          width: double.infinity,
          color: _green,
          padding: const pw.EdgeInsets.fromLTRB(48, 90, 48, 60),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              PdfBranding.coatOfArms(size: 70),
              pw.SizedBox(height: 28),
              _text('UbuntuID', style: pw.TextStyle(fontSize: 16, color: _goldLight, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _text('Citizen User Guide',
                  style: pw.TextStyle(fontSize: 34, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              _text('How to find your digital ID, documents, services and settings - step by step, with pictures.',
                  style: const pw.TextStyle(fontSize: 13, color: PdfColors.white, lineSpacing: 3)),
            ],
          ),
        ),
        pw.Container(height: 6, color: _gold),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(48, 40, 48, 48),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _text('How to use this guide', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _ink)),
                pw.SizedBox(height: 10),
                for (final line in [
                  'Each section answers one "How do I...?" question.',
                  'The picture shows the screen. The parts to tap are circled in gold and numbered.',
                  'The numbers in the picture match the numbered steps beside it.',
                  '"Where to find it" gives the quickest route, e.g. Bottom bar > Services.',
                  'You can open this guide in the app at any time: tap the Guide button at the top of the screen.',
                ])
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 7),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 6,
                          height: 6,
                          margin: const pw.EdgeInsets.only(top: 4, right: 10),
                          decoration: const pw.BoxDecoration(color: _gold, shape: pw.BoxShape.circle),
                        ),
                        pw.Expanded(child: _text(line, style: const pw.TextStyle(fontSize: 11, color: _ink, lineSpacing: 2))),
                      ],
                    ),
                  ),
                pw.Spacer(),
                _text('Generated ${DateFormat('d MMMM y').format(generated)}',
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _runningHeader() => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _border))),
        child: pw.Row(
          children: [
            PdfBranding.coatOfArms(size: 16),
            pw.SizedBox(width: 8),
            _text('UbuntuID Citizen User Guide', style: pw.TextStyle(fontSize: 9, color: _green, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  static pw.Widget _footer(pw.Context context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: _text('Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
      );

  static pw.Widget _heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: _text(text, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _green)),
      );

  static pw.Widget _contents(List<GuideTopic> topics) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _heading('Contents'),
        for (final (i, topic) in topics.indexed)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.5))),
            child: pw.Row(
              children: [
                _numberBadge(i + 1, size: 18),
                pw.SizedBox(width: 10),
                pw.Expanded(child: _text(topic.title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                _text(topic.where, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _numberBadge(int n, {double size = 16, PdfColor color = _green}) => pw.Container(
        width: size,
        height: size,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
        child: _text('$n', style: pw.TextStyle(fontSize: size * 0.5, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _topic(int number, GuideTopic topic) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 22),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              _numberBadge(number, size: 24),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _text(topic.title, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: _ink)),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _text(topic.summary, style: const pw.TextStyle(fontSize: 10.5, color: _ink, lineSpacing: 2)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(color: _greenLight, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: 'Where to find it:  ', style: pw.TextStyle(fontSize: 9.5, color: _green, fontWeight: pw.FontWeight.bold)),
                  pw.TextSpan(text: pdfSafe(topic.where), style: const pw.TextStyle(fontSize: 9.5, color: _ink)),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 210, child: pw.SvgImage(svg: topic.mockup.toSvg())),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _text('Steps', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
                    pw.SizedBox(height: 8),
                    for (final (i, step) in topic.steps.indexed)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 9),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _numberBadge(i + 1, color: _gold),
                            pw.SizedBox(width: 8),
                            pw.Expanded(child: _text(step, style: const pw.TextStyle(fontSize: 10, lineSpacing: 2))),
                          ],
                        ),
                      ),
                    if (topic.tip != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(9),
                        decoration: const pw.BoxDecoration(
                          color: _goldLight,
                          border: pw.Border(left: pw.BorderSide(color: _gold, width: 3)),
                        ),
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(text: 'Tip:  ', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                              pw.TextSpan(text: pdfSafe(topic.tip!), style: const pw.TextStyle(fontSize: 9.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _quickReference(List<GuideTopic> topics) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _heading('Quick reference: where is everything?'),
        pw.TableHelper.fromTextArray(
          headers: ['I want to...', 'Where to find it'],
          data: [for (final t in topics) [pdfSafe(t.title), pdfSafe(t.where)]],
          headerStyle: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: _green),
          cellStyle: const pw.TextStyle(fontSize: 9.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          oddRowDecoration: const pw.BoxDecoration(color: _greenLight),
          border: pw.TableBorder.all(color: _border, width: 0.5),
        ),
        pw.SizedBox(height: 16),
        _text('Still stuck? Open Settings > Feedback in the app to tell us what you were trying to do.',
            style: const pw.TextStyle(fontSize: 10, color: _muted)),
      ],
    );
  }
}
