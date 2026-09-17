import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// CSV/PDF export for admin report screens (Users, Organisations, Audit
/// Logs, Compliance Audits) and citizen credential downloads (Digital
/// Identity screen) -- shares an in-memory file via the platform share
/// sheet (desktop save dialog / mobile share sheet / browser download on
/// web), so no extra file-system permission handling is needed on any
/// platform.
class ReportExport {
  ReportExport._();

  static const _coatOfArmsAsset = 'assets/branding/coat_of_arms.svg';

  static String _referenceId(String filename) {
    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final prefix = filename.split('.').first.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
    return 'UID-${prefix.substring(0, prefix.length < 6 ? prefix.length : 6)}-$stamp';
  }

  static Future<void> exportCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final buffer = StringBuffer()..writeln(headers.map(_csvCell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_csvCell).join(','));
    }
    final bytes = Uint8List.fromList(buffer.toString().codeUnits);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: filename, mimeType: 'text/csv')],
        fileNameOverrides: [filename],
      ),
    );
  }

  static String _csvCell(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static Future<void> exportPdf({
    required String filename,
    required String title,
    String? subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    String? referenceId,
  }) async {
    final coatOfArmsSvg = await rootBundle.loadString(_coatOfArmsAsset);
    final refId = referenceId ?? _referenceId(filename);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        // A neutral dark-green/gold-adjacent header, not the exact app
        // brand hex -- a printed government report reads as intentionally
        // plain, not an attempt to reproduce official letterhead.
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 42,
                  height: 42,
                  child: pw.SvgImage(svg: coatOfArmsSvg),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      if (subtitle != null)
                        pw.Text(subtitle, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'UbuntuID -- generated ${DateTime.now().toIso8601String().split('T').first}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: refId,
                      width: 130,
                      height: 40,
                      drawText: false,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(refId, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
        ],
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Document ref: $refId',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: filename);
  }
}
