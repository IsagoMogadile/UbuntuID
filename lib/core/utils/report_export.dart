import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'pdf_text.dart';

/// Excel/PDF export for admin report screens (Users, Organisations, Audit
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

  static const _xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Shares [headers]/[rows] as a styled .xlsx workbook: the coat of arms
  /// with "UbuntuID" beside it, the report title, then a bordered table
  /// with bold, centred column headings.
  static Future<void> exportExcel({
    required String filename,
    required String title,
    String? subtitle,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final bytes = await buildExcel(title: title, subtitle: subtitle, headers: headers, rows: rows);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: filename, mimeType: _xlsxMime)],
        fileNameOverrides: [filename],
      ),
    );
  }

  static Future<Uint8List> buildExcel({
    required String title,
    String? subtitle,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    // Column A is a narrow gutter that holds the coat of arms, so the
    // "UbuntuID" heading in B1 sits right beside it and the table starts
    // in column B.
    const firstCol = 1;
    const headerRow = 4;
    const logoHeightPx = 76.0;
    const gutterWidthChars = 10.0;

    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', 'Report');
    final sheet = excel['Report'];

    void put(int col, int row, String value, CellStyle style) => sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          TextCellValue(value),
          cellStyle: style,
        );

    final generated = 'Generated ${DateTime.now().toIso8601String().split('T').first}';
    put(firstCol, 0, 'UbuntuID', CellStyle(
      bold: true,
      fontSize: 20,
      verticalAlign: VerticalAlign.Center,
      fontColorHex: ExcelColor.fromHexString('#FF00512C'),
    ));
    put(firstCol, 1, title, CellStyle(bold: true, fontSize: 13, verticalAlign: VerticalAlign.Center));
    put(firstCol, 2, subtitle == null ? generated : '$subtitle  |  $generated', CellStyle(
      italic: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#FF54615B'),
    ));
    sheet.setRowHeight(0, 30);
    sheet.setRowHeight(1, 20);
    sheet.setRowHeight(2, 16);

    final thin = Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black);
    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      backgroundColorHex: ExcelColor.fromHexString('#FFD9D9D9'),
      leftBorder: thin,
      rightBorder: thin,
      topBorder: thin,
      bottomBorder: thin,
    );
    final bodyStyle = CellStyle(
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: thin,
      rightBorder: thin,
      topBorder: thin,
      bottomBorder: thin,
    );

    for (var c = 0; c < headers.length; c++) {
      put(firstCol + c, headerRow, headers[c], headerStyle);
    }
    sheet.setRowHeight(headerRow, 22);
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < headers.length; c++) {
        put(firstCol + c, headerRow + 1 + r, c < rows[r].length ? rows[r][c] : '', bodyStyle);
      }
    }

    sheet.setColumnWidth(0, gutterWidthChars);
    for (var c = 0; c < headers.length; c++) {
      var longest = headers[c].length;
      for (final row in rows) {
        if (c < row.length && row[c].length > longest) longest = row[c].length;
      }
      sheet.setColumnWidth(firstCol + c, (longest + 4).clamp(12, 50).toDouble());
    }

    final (png, logoSize) = await _coatOfArmsPng(height: logoHeightPx);
    // Excel column width in characters -> pixels, roughly (Calibri 11).
    const gutterPx = gutterWidthChars * 7 + 5;
    return _embedLogo(
      excel.encode()!,
      png,
      logoSize,
      offsetX: ((gutterPx - logoSize.width) / 2).clamp(0, gutterPx),
      offsetY: 4,
    );
  }

  /// Renders the coat of arms SVG to a PNG [height] px tall (at 3x, so it
  /// stays sharp when the sheet is zoomed). The `excel` package can't
  /// embed images at all, hence [_embedLogo].
  static Future<(Uint8List, ui.Size)> _coatOfArmsPng({required double height}) async {
    final info = await vg.loadPicture(const SvgAssetLoader(_coatOfArmsAsset), null);
    try {
      const scale = 3.0;
      final width = height * info.size.width / info.size.height;
      final pxW = (width * scale).round();
      final pxH = (height * scale).round();
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
        ..scale(pxW / info.size.width, pxH / info.size.height)
        ..drawPicture(info.picture);
      final picture = recorder.endRecording();
      final image = await picture.toImage(pxW, pxH);
      picture.dispose();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return (data!.buffer.asUint8List(), ui.Size(width, height));
    } finally {
      info.picture.dispose();
    }
  }

  /// Adds [png] to the workbook's (single) sheet as a picture anchored in
  /// cell A1, by writing the parts an .xlsx needs for an image: the media
  /// file, a drawing referencing it, the sheet -> drawing relationship,
  /// and the content-type entries.
  static Uint8List _embedLogo(
    List<int> xlsx,
    Uint8List png,
    ui.Size size, {
    required double offsetX,
    required double offsetY,
  }) {
    const emuPerPx = 9525;
    const relNs = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    const pkgRelNs = 'http://schemas.openxmlformats.org/package/2006/relationships';
    const xmlDecl = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
    final cx = (size.width * emuPerPx).round();
    final cy = (size.height * emuPerPx).round();

    final source = ZipDecoder().decodeBytes(xlsx);
    String read(ArchiveFile f) => utf8.decode(f.content as List<int>);
    final sheetPath = source.files
        .map((f) => f.name)
        .firstWhere((n) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(n));
    final sheetRelsPath = 'xl/worksheets/_rels/${sheetPath.split('/').last}.rels';
    final sheetRelsFile = source.findFile(sheetRelsPath);
    final sheetRelsXml = sheetRelsFile == null ? null : read(sheetRelsFile);

    // The `excel` package's blank template already links the sheet to an
    // (empty) drawings/drawing1.xml. Reuse that slot -- adding a second
    // relationship/content-type entry for the same part makes Excel report
    // the file as corrupt and offer to repair it.
    final existing = sheetRelsXml == null
        ? null
        : RegExp(r'<Relationship [^>]*Id="([^"]+)"[^>]*Type="[^"]*/drawing"[^>]*Target="\.\./drawings/([^"]+)"')
            .firstMatch(sheetRelsXml);
    final sheetRelId = existing?.group(1) ?? 'rIdUbuntuIdLogo';
    final drawingName = existing?.group(2) ?? 'drawing1.xml';
    final drawingPath = 'xl/drawings/$drawingName';
    final sheetRel = '<Relationship Id="$sheetRelId" Type="$relNs/drawing" Target="../drawings/$drawingName"/>';

    final out = Archive();
    void add(String name, List<int> bytes) => out.addFile(ArchiveFile(name, bytes.length, bytes));

    for (final file in source.files) {
      if (!file.isFile) continue;
      if (file.name == sheetPath) {
        var xml = read(file);
        if (!xml.contains('<drawing ')) {
          if (!xml.contains('xmlns:r=')) xml = xml.replaceFirst('<worksheet ', '<worksheet xmlns:r="$relNs" ');
          // <drawing> must come before these worksheet elements, if present.
          final later = RegExp(r'<(legacyDrawing|legacyDrawingHF|picture|oleObjects|controls|'
                  r'webPublishItems|tableParts|extLst)[\s/>]')
              .firstMatch(xml);
          final at = later?.start ?? xml.lastIndexOf('</worksheet>');
          xml = '${xml.substring(0, at)}<drawing r:id="$sheetRelId"/>${xml.substring(at)}';
        }
        add(file.name, utf8.encode(xml));
      } else if (file.name == sheetRelsPath) {
        add(
          file.name,
          utf8.encode(existing != null ? sheetRelsXml! : sheetRelsXml!.replaceFirst('</Relationships>', '$sheetRel</Relationships>')),
        );
      } else if (file.name == '[Content_Types].xml') {
        var xml = read(file);
        if (!xml.contains('Extension="png"')) {
          xml = xml.replaceFirst('</Types>', '<Default Extension="png" ContentType="image/png"/></Types>');
        }
        if (!xml.contains('PartName="/$drawingPath"')) {
          xml = xml.replaceFirst(
            '</Types>',
            '<Override PartName="/$drawingPath" '
                'ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/></Types>',
          );
        }
        add(file.name, utf8.encode(xml));
      } else if (file.name != drawingPath) {
        add(file.name, file.content as List<int>);
      }
    }
    if (sheetRelsXml == null) {
      add(sheetRelsPath, utf8.encode('$xmlDecl<Relationships xmlns="$pkgRelNs">$sheetRel</Relationships>'));
    }
    add('xl/media/ubuntuid_coat_of_arms.png', png);
    add(
      'xl/drawings/_rels/$drawingName.rels',
      utf8.encode('$xmlDecl<Relationships xmlns="$pkgRelNs">'
          '<Relationship Id="rId1" Type="$relNs/image" Target="../media/ubuntuid_coat_of_arms.png"/>'
          '</Relationships>'),
    );
    add(
      drawingPath,
      utf8.encode('$xmlDecl<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" '
          'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="$relNs">'
          '<xdr:oneCellAnchor>'
          '<xdr:from><xdr:col>0</xdr:col><xdr:colOff>${(offsetX * emuPerPx).round()}</xdr:colOff>'
          '<xdr:row>0</xdr:row><xdr:rowOff>${(offsetY * emuPerPx).round()}</xdr:rowOff></xdr:from>'
          '<xdr:ext cx="$cx" cy="$cy"/>'
          '<xdr:pic>'
          '<xdr:nvPicPr><xdr:cNvPr id="2" name="Coat of arms" descr="Coat of arms"/>'
          '<xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr></xdr:nvPicPr>'
          '<xdr:blipFill><a:blip r:embed="rId1"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill>'
          '<xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
          '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr>'
          '</xdr:pic>'
          '<xdr:clientData/>'
          '</xdr:oneCellAnchor>'
          '</xdr:wsDr>'),
    );
    return Uint8List.fromList(ZipEncoder().encode(out)!);
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
    title = pdfSafe(title);
    subtitle = subtitle == null ? null : pdfSafe(subtitle);
    headers = [for (final h in headers) pdfSafe(h)];
    rows = [
      for (final row in rows) [for (final cell in row) pdfSafe(cell)],
    ];

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
                        'UbuntuID - generated ${DateTime.now().toIso8601String().split('T').first}',
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
