import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/file_names.dart';
import '../../../core/utils/pdf_branding.dart';
import '../../../core/utils/pdf_text.dart';
import '../domain/credential_item.dart';
import '../domain/digital_identity.dart';
import '../domain/nsc_statement.dart';
import 'document_avatar.dart'; 

/// implemented by Buhle Ndlovu : The citizen a prototype document is generated for -- built only from
/// their own UbuntuID record ([DigitalIdentity] plus current address).
class DocumentHolder {
  DocumentHolder({
    required this.firstNames,
    required this.surname,
    required this.idNumber,
    required this.dateOfBirth,
    required this.feminine,
    required this.citizenshipLabel,
    required this.registeredAt,
    this.address,
  }) : avatar = DocumentAvatar(seed: idNumber, feminine: feminine);

  /// Sex and citizenship fall back to what the SA ID number itself encodes
  /// (digits 7-10: 0000-4999 female; digit 11: 0 citizen, 1 permanent
  /// resident) when the citizen row doesn't carry them.
  factory DocumentHolder.fromIdentity(DigitalIdentity identity, {String? address}) {
    final id = identity.idNumber;
    final gender = identity.gender?.toLowerCase();
    final feminine = gender != null && gender.isNotEmpty
        ? gender.startsWith('f')
        : (id.length >= 10 && (int.tryParse(id.substring(6, 10)) ?? 5000) < 5000);
    final status = identity.citizenshipStatus?.toLowerCase();
    final citizen = status != null && status.isNotEmpty ? status == 'citizen' : (id.length < 11 || id[10] == '0');
    return DocumentHolder(
      firstNames: identity.firstName,
      surname: identity.lastName,
      idNumber: id,
      dateOfBirth: identity.dateOfBirth,
      feminine: feminine,
      citizenshipLabel: citizen ? 'South African citizen' : 'Permanent resident',
      registeredAt: identity.registeredAt,
      address: address,
    );
  }

  final String firstNames;
  final String surname;
  final String idNumber;
  final DateTime dateOfBirth;
  final bool feminine;
  final String citizenshipLabel;
  final DateTime registeredAt;
  final String? address;
  final DocumentAvatar avatar;

  String get fullName => '$firstNames $surname';
  String get sexLabel => feminine ? 'F' : 'M';
  String get sexWord => feminine ? 'Female' : 'Male';

  /// "900618 5086 08 4" -- grouped for readability, as SA documents print it.
  String get groupedIdNumber => idNumber.length == 13
      ? '${idNumber.substring(0, 6)} ${idNumber.substring(6, 10)} ${idNumber.substring(10, 12)} ${idNumber.substring(12)}'
      : idNumber;
}

/// Builds UbuntuID's downloadable credential documents.
///
/// These are prototype illustrations for a final-year university project,
/// inspired by the information hierarchy of familiar South African documents
/// (ID card front/back, driver's licence, matric certificate, ...) but never
/// a copy of one: there is no coat of arms, no seal, no hologram, no barcode
/// or machine-readable zone, and no signature. Every page carries a
/// "DEMONSTRATION / PROTOTYPE" banner, footer and diagonal watermark that
/// print with the page.
class CredentialDocuments {
  CredentialDocuments._();

  static final _cardDate = DateFormat('dd MMM yyyy');
  static final _longDate = DateFormat('d MMMM yyyy');

  static String _card(DateTime? d) => d == null ? 'Not on record' : _cardDate.format(d).toUpperCase();
  static String _long(DateTime? d) => d == null ? 'Not on record' : _longDate.format(d);

  static DateTime? _date(Map<String, dynamic>? record, String key) {
    final value = record?[key];
    return value is String ? DateTime.tryParse(value) : null;
  }

  static String _value(Map<String, dynamic>? record, String key, {String fallback = 'Not on record'}) {
    final value = record?[key];
    if (value == null || '$value'.trim().isEmpty) return fallback;
    return '$value';
  }

  static String _status(String raw) {
    final text = raw.replaceAll('_', ' ').trim();
    return text.isEmpty ? 'Unknown' : text[0].toUpperCase() + text.substring(1);
  }

  // ---------------------------------------------------------------------
  // Shared building blocks
  // ---------------------------------------------------------------------

  static const _green = PdfColor.fromInt(0xFF00723F);
  static const _greenDark = PdfColor.fromInt(0xFF00512C);
  static const _gold = PdfColor.fromInt(0xFFC9962C);
  static const _ink = PdfColor.fromInt(0xFF1B1F1D);
  static const _muted = PdfColor.fromInt(0xFF54615B);
  static const _warn = PdfColor.fromInt(0xFFB3261E);
  static const _warnBg = PdfColor.fromInt(0xFFFBE9E8);

  static pw.TextStyle _label() => const pw.TextStyle(fontSize: 6.5, color: _muted, letterSpacing: 0.4);
  static pw.TextStyle _val({double size = 10}) =>
      pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold, color: _ink);

  static pw.Widget _text(String text, {pw.TextStyle? style, pw.TextAlign? align}) =>
      pw.Text(pdfSafe(text), style: style, textAlign: align);

  /// Red-bordered disclaimer, at the top of every page.
  static pw.Widget _disclaimerBanner(String headline) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: pw.BoxDecoration(
      color: _warnBg,
      border: pw.Border.all(color: _warn, width: 1.2),
    ),
    child: pw.Column(
      children: [
        _text(
          headline,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _warn),
          align: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        _text(
          'Generated by UbuntuID, a final-year university prototype, from simulated data. '
          'Not issued by, or affiliated with, the South African Government. Not valid for any official purpose.',
          style: const pw.TextStyle(fontSize: 7, color: _warn),
          align: pw.TextAlign.center,
        ),
      ],
    ),
  );

  static pw.Widget _footer(String reference) => pw.Column(
    children: [
      pw.Divider(color: PdfColors.grey400, thickness: 0.5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _text(
            'UbuntuID prototype document - simulated data - not a government document',
            style: const pw.TextStyle(fontSize: 7, color: _muted),
          ),
          _text('Ref $reference', style: const pw.TextStyle(fontSize: 7, color: _muted)),
        ],
      ),
    ],
  );

  /// A diagonal watermark drawn over the content, so it survives printing
  /// and photocopying of any part of the page.
  static pw.Widget _watermark(String text) => pw.FullPage(
    ignoreMargins: true,
    child: pw.Center(
      child: pw.Transform.rotate(
        angle: 0.55,
        child: pw.Opacity(
          opacity: 0.10,
          child: _text(
            text,
            style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold, color: _warn),
            align: pw.TextAlign.center,
          ),
        ),
      ),
    ),
  );

  static pw.Page _page({
    required String headline,
    required String watermark,
    required String reference,
    required List<pw.Widget> children,
  }) {
    return pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 26),
        buildForeground: (_) => _watermark(watermark),
      ),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [_disclaimerBanner(headline), pw.SizedBox(height: 16), ...children, pw.Spacer(), _footer(reference)],
      ),
    );
  }

  /// Document title block: the coat of arms,
  /// the document name and the simulated issuing department.
  static pw.Widget _docHeader({required String title, required String authority, String? subtitle}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfBranding.coatOfArms(size: 50),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _text(
                'UBUNTUID PROTOTYPE',
                style: pw.TextStyle(fontSize: 8, color: _green, letterSpacing: 1.5, fontWeight: pw.FontWeight.bold),
              ),
              _text(
                title,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _ink),
              ),
              if (subtitle != null) _text(subtitle, style: const pw.TextStyle(fontSize: 9, color: _muted)),
              pw.SizedBox(height: 2),
              _text('Simulated issuing authority: $authority', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _field(String label, String value, {double size = 10}) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _text(label.toUpperCase(), style: _label()),
        pw.SizedBox(height: 1),
        _text(value, style: _val(size: size)),
      ],
    ),
  );

  static pw.Widget _sectionTitle(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _text(
          title.toUpperCase(),
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _greenDark, letterSpacing: 1),
        ),
        pw.SizedBox(height: 3),
        pw.Container(height: 1.2, color: _gold),
      ],
    ),
  );

  /// Two-column label/value table for letters and certificates.
  static pw.Widget _detailsTable(List<(String, String)> rows) => pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
    children: [
      for (final (label, value) in rows)
        pw.TableRow(
          children: [
            pw.Container(
              color: PdfColors.grey100,
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: _text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: _text(value, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
    ],
  );

  /// Holder box shown on letters/certificates -- same avatar as the cards.
  static pw.Widget _holderPanel(DocumentHolder holder) => pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.6)),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        holder.avatar.build(width: 62, height: 78),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _field('Surname', holder.surname.toUpperCase()),
              _field('Forenames', holder.firstNames.toUpperCase()),
              pw.Row(
                children: [
                  pw.Expanded(child: _field('Identity number', holder.groupedIdNumber)),
                  pw.Expanded(child: _field('Date of birth', _card(holder.dateOfBirth))),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static pw.Widget _statusBox({required String heading, required String status, required bool positive}) {
    final colour = positive ? _green : _warn;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: colour, width: 1.5)),
      child: pw.Column(
        children: [
          _text(heading.toUpperCase(), style: _label()),
          pw.SizedBox(height: 4),
          _text(
            status.toUpperCase(),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: colour, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  static pw.Widget _note(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8),
    child: _text(
      text,
      style: pw.TextStyle(fontSize: 8, color: _muted, fontStyle: pw.FontStyle.italic),
    ),
  );

  /// The card itself -- a rounded rectangle at a card's 85.6 x 54 mm
  /// proportions, printed larger than life so it reads clearly on A4.
  static pw.Widget _cardFrame({required PdfColor tint, required PdfColor band, required pw.Widget child}) =>
      pw.Container(
        width: 462,
        height: 291,
        decoration: pw.BoxDecoration(
          color: tint,
          borderRadius: pw.BorderRadius.circular(14),
          border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 14,
          verticalRadius: 14,
          child: pw.Stack(
            children: [
              pw.Positioned(left: 0, right: 0, top: 0, child: pw.Container(height: 6, color: band)),
              pw.Padding(padding: const pw.EdgeInsets.fromLTRB(16, 16, 16, 12), child: child),
              _overprint(),
            ],
          ),
        ),
      );

  /// Large "PROTOTYPE" overprint inside a card/data page itself, so a
  /// cropped image of just that part is still marked.
  static pw.Widget _overprint() => pw.Center(
    child: pw.Transform.rotate(
      angle: 0.35,
      child: pw.Opacity(
        opacity: 0.16,
        child: _text(
          'PROTOTYPE',
          style: pw.TextStyle(fontSize: 64, fontWeight: pw.FontWeight.bold, color: _warn, letterSpacing: 4),
        ),
      ),
    ),
  );

  static pw.Widget _cardTitleRow(String left, String right) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      _text(
        left,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _greenDark, letterSpacing: 1.2),
      ),
      _text(
        right,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _warn, letterSpacing: 0.8),
      ),
    ],
  );

  static pw.Widget _sideLabel(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: _text(
      text,
      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _muted, letterSpacing: 2),
    ),
  );

  // ---------------------------------------------------------------------
  // Identity document -- two pages, FRONT then BACK.
  // ---------------------------------------------------------------------

  static Future<Uint8List> identityDocument(DocumentHolder holder) async {
    await PdfBranding.load();
    const headline = 'DEMONSTRATION / PROTOTYPE DOCUMENT - NOT A REAL GOVERNMENT-ISSUED ID DOCUMENT';
    const watermark = 'UBUNTUID DEMONSTRATION\nNOT A REAL ID DOCUMENT';
    final idTail = holder.idNumber.length >= 4
        ? holder.idNumber.substring(holder.idNumber.length - 4)
        : holder.idNumber;
    final reference = 'UID-ID-$idTail';
    const tint = PdfColor.fromInt(0xFFEAF2EC);

    final front = _cardFrame(
      tint: tint,
      band: _green,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _cardTitleRow('UBUNTUID  -  IDENTITY CARD', 'DEMONSTRATION ONLY'),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              holder.avatar.build(width: 108, height: 136),
              pw.SizedBox(width: 18),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _field('Surname', holder.surname.toUpperCase(), size: 12),
                    _field('Names', holder.firstNames.toUpperCase(), size: 12),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _field('Sex', holder.sexLabel)),
                        pw.Expanded(
                          child: _field(
                            'Nationality',
                            holder.citizenshipLabel == 'South African citizen' ? 'RSA' : 'RSA (PR)',
                          ),
                        ),
                      ],
                    ),
                    _field('Identity number', holder.groupedIdNumber, size: 12),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _field('Date of birth', _card(holder.dateOfBirth))),
                        pw.Expanded(child: _field('Status', holder.citizenshipLabel.toUpperCase())),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 120, height: 0.6, color: PdfColors.grey600),
                  pw.SizedBox(height: 2),
                  _text('Holder signature (not captured in prototype)', style: _label()),
                ],
              ),
              _text('Side 1 of 2', style: _label()),
            ],
          ),
        ],
      ),
    );

    final back = _cardFrame(
      tint: tint,
      band: _green,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _cardTitleRow('UBUNTUID  -  IDENTITY CARD (REVERSE)', 'DEMONSTRATION ONLY'),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _field('Identity number', holder.groupedIdNumber, size: 12),
                    _field('Date of issue (UbuntuID registration)', _card(holder.registeredAt)),
                    _field('Issued by (simulated)', 'DEPARTMENT OF HOME AFFAIRS'),
                    _field('Conditions', 'NONE'),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              holder.avatar.build(width: 54, height: 68, caption: false),
            ],
          ),
          pw.SizedBox(height: 4),
          // Where a real card carries machine-readable data, the prototype
          // deliberately leaves a labelled blank instead.
          pw.Container(
            width: double.infinity,
            height: 46,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.grey500, width: 0.6, style: pw.BorderStyle.dashed),
            ),
            child: _text(
              'Machine-readable data intentionally not reproduced in this prototype',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [_text('Side 2 of 2', style: _label())],
          ),
        ],
      ),
    );

    final doc = pw.Document(title: 'UbuntuID prototype identity document', author: 'UbuntuID prototype');
    doc
      ..addPage(
        _page(
          headline: headline,
          watermark: watermark,
          reference: '$reference-F',
          children: [
            _docHeader(
              title: 'Identity Document - Front',
              authority: 'Department of Home Affairs',
              subtitle: 'Page 1 of 2: front of the identity card',
            ),
            pw.SizedBox(height: 18),
            _sideLabel('FRONT'),
            pw.Center(child: front),
            _sectionTitle('Holder particulars (from UbuntuID record)'),
            _detailsTable([
              ('Full name', holder.fullName),
              ('Identity number', holder.groupedIdNumber),
              ('Date of birth', _long(holder.dateOfBirth)),
              ('Sex', holder.sexWord),
              ('Citizenship', holder.citizenshipLabel),
            ]),
            _note(
              'Page 2 shows the reverse of the same card. When an identity card is photocopied for certification, '
              'both sides are copied together - the front identifies the holder, the reverse carries the issue '
              'details. This prototype reproduces that two-sided layout for demonstration only.',
            ),
          ],
        ),
      )
      ..addPage(
        _page(
          headline: headline,
          watermark: watermark,
          reference: '$reference-B',
          children: [
            _docHeader(
              title: 'Identity Document - Back',
              authority: 'Department of Home Affairs',
              subtitle: 'Page 2 of 2: reverse of the identity card for ${holder.fullName}',
            ),
            pw.SizedBox(height: 18),
            _sideLabel('BACK'),
            pw.Center(child: back),
            _sectionTitle('Additional particulars'),
            _detailsTable([
              ('Residential address (UbuntuID record)', holder.address ?? 'No address on file'),
              ('Registered on UbuntuID', _long(holder.registeredAt)),
            ]),
            _sectionTitle('Certification of copy (illustration)'),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey500, width: 0.6, style: pw.BorderStyle.dashed),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _text(
                    'Space shown to illustrate where a commissioner of oaths would certify a copy of both sides. '
                    'A copy of this prototype cannot be certified - it is not an identity document.',
                    style: const pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Row(
                    children: [
                      for (final label in ['Name', 'Designation', 'Date'])
                        pw.Expanded(
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.only(right: 12),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Container(height: 0.6, color: PdfColors.grey600),
                                pw.SizedBox(height: 2),
                                _text(label, style: _label()),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    return doc.save();
  }

  // ---------------------------------------------------------------------
  // Credentials -- one layout per type.
  // ---------------------------------------------------------------------

  static Future<Uint8List> credentialDocument(
    DocumentHolder holder,
    CredentialItem credential,
    Map<String, dynamic>? record,
  ) async {
    await PdfBranding.load();
    final doc = pw.Document(title: 'UbuntuID prototype - ${credential.typeName}', author: 'UbuntuID prototype');
    final reference =
        'UID-${credential.typeCode.isEmpty ? 'DOC' : credential.typeCode}-'
        '${credential.credentialId.substring(0, credential.credentialId.length < 8 ? credential.credentialId.length : 8).toUpperCase()}';
    doc.addPage(switch (credential.typeCode) {
      'DRIVERS_LICENCE' => _driversLicence(holder, credential, record, reference),
      'PASSPORT' => _passport(holder, credential, record, reference),
      'NSC' => _matricCertificate(holder, credential, record, reference),
      'TERTIARY_QUALIFICATION' => _tertiary(holder, credential, reference),
      'TAX_COMPLIANCE' => _taxCompliance(holder, credential, record, reference),
      'CRIMINAL_CLEARANCE' => _policeClearance(holder, credential, record, reference),
      'LABOUR_STATUS' => _employmentLetter(holder, credential, record, reference),
      'SASSA_STATUS' => _grantLetter(holder, credential, record, reference),
      _ => _generic(holder, credential, reference),
    });
    return doc.save();
  }

  static const _licenceCodes = {
    'A1': 'Motorcycle up to 125 cm3',
    'A': 'Motorcycle over 125 cm3',
    'B': 'Light motor vehicle up to 3 500 kg',
    'EB': 'Light motor vehicle with heavy trailer',
    'C1': 'Heavy motor vehicle 3 500 - 16 000 kg',
    'C': 'Heavy motor vehicle over 16 000 kg',
    'EC1': 'Heavy vehicle (C1) with trailer',
    'EC': 'Heavy vehicle (C) with trailer',
  };

  static pw.Page _driversLicence(
    DocumentHolder holder,
    CredentialItem credential,
    Map<String, dynamic>? record,
    String reference,
  ) {
    final code = _value(record, 'licence_code');
    final issue = _date(record, 'issue_date') ?? credential.issuedDate;
    final expiry = _date(record, 'expiry_date') ?? credential.expiryDate;
    const tint = PdfColor.fromInt(0xFFF6ECEA);
    const band = PdfColor.fromInt(0xFF9C4A3C);

    final card = _cardFrame(
      tint: tint,
      band: band,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _cardTitleRow("UBUNTUID  -  DRIVING LICENCE", 'DEMONSTRATION ONLY'),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              holder.avatar.build(width: 100, height: 126),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _field('1. Surname', holder.surname.toUpperCase(), size: 11),
                    _field('2. Names', holder.firstNames.toUpperCase(), size: 11),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _field('3. ID number', holder.groupedIdNumber, size: 9)),
                        pw.Expanded(child: _field('Date of birth', _card(holder.dateOfBirth), size: 9)),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _field('4a. Valid from', _card(issue), size: 9)),
                        pw.Expanded(child: _field('4b. Valid to', _card(expiry), size: 9)),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _field('5. Licence no. (UbuntuID ref)', _value(record, 'licence_number'), size: 9),
                        ),
                        pw.Expanded(child: _field('9. Code', code, size: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _text('Restrictions: none recorded', style: _label()),
              _text('Status: ${_status(credential.status).toUpperCase()}', style: _label()),
            ],
          ),
        ],
      ),
    );

    return _page(
      headline: "DEMONSTRATION / PROTOTYPE - NOT A REAL DRIVER'S LICENCE",
      watermark: "UBUNTUID DEMONSTRATION\nNOT A REAL DRIVER'S LICENCE",
      reference: reference,
      children: [
        _docHeader(title: "Driver's Licence", authority: credential.issuingDepartment),
        pw.SizedBox(height: 18),
        pw.Center(child: card),
        _sectionTitle('Licence particulars'),
        _detailsTable([
          ('Licence code', code),
          ('Vehicle category', _licenceCodes[code] ?? 'Not on record'),
          ('First issued', _long(issue)),
          ('Valid until', _long(expiry)),
          ('Vehicle / driver restrictions', 'None recorded in UbuntuID'),
          ('Professional driving permit', 'Not on record'),
          ('Record status', _status(_value(record, 'status', fallback: credential.status))),
        ]),
        _note(
          'The numbered fields follow the order commonly printed on a South African licence card, for familiarity. '
          'The licence number is an UbuntuID-generated reference, not a real licence number.',
        ),
      ],
    );
  }

  static pw.Page _passport(
    DocumentHolder holder,
    CredentialItem credential,
    Map<String, dynamic>? record,
    String reference,
  ) {
    final issue = _date(record, 'issue_date') ?? credential.issuedDate;
    final expiry = _date(record, 'expiry_date') ?? credential.expiryDate;
    const tint = PdfColor.fromInt(0xFFEDEFF5);
    const band = PdfColor.fromInt(0xFF2C3E66);

    final dataPage = pw.Container(
      width: 462,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: tint,
        border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Stack(
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(height: 5, color: band),
              pw.SizedBox(height: 8),
              _cardTitleRow('UBUNTUID  -  PASSPORT DATA PAGE', 'DEMONSTRATION ONLY'),
              pw.SizedBox(height: 12),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  holder.avatar.build(width: 104, height: 130),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Expanded(child: _field('Type', 'P')),
                            pw.Expanded(
                              flex: 2,
                              child: _field('Passport no. (UbuntuID ref)', _value(record, 'passport_number')),
                            ),
                          ],
                        ),
                        _field('Surname', holder.surname.toUpperCase(), size: 11),
                        _field('Given names', holder.firstNames.toUpperCase(), size: 11),
                        pw.Row(
                          children: [
                            pw.Expanded(child: _field('Nationality', 'SOUTH AFRICAN')),
                            pw.Expanded(child: _field('Sex', holder.sexLabel)),
                          ],
                        ),
                        pw.Row(
                          children: [
                            pw.Expanded(child: _field('Date of birth', _card(holder.dateOfBirth))),
                            pw.Expanded(child: _field('Identity no.', holder.idNumber)),
                          ],
                        ),
                        pw.Row(
                          children: [
                            pw.Expanded(child: _field('Date of issue', _card(issue))),
                            pw.Expanded(child: _field('Date of expiry', _card(expiry))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                height: 40,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: PdfColors.grey500, width: 0.6, style: pw.BorderStyle.dashed),
                ),
                child: _text(
                  'Machine-readable zone intentionally not reproduced in this prototype',
                  style: const pw.TextStyle(fontSize: 8, color: _muted),
                ),
              ),
            ],
          ),
          pw.Positioned.fill(child: _overprint()),
        ],
      ),
    );

    return _page(
      headline: 'DEMONSTRATION / PROTOTYPE - NOT A REAL PASSPORT',
      watermark: 'UBUNTUID DEMONSTRATION\nNOT A REAL PASSPORT',
      reference: reference,
      children: [
        _docHeader(title: 'Passport - Data Page', authority: credential.issuingDepartment),
        pw.SizedBox(height: 18),
        pw.Center(child: dataPage),
        _sectionTitle('Passport record'),
        _detailsTable([
          ('Holder', holder.fullName),
          ('Issued', _long(issue)),
          ('Expires', _long(expiry)),
          ('Record status', _status(_value(record, 'status', fallback: credential.status))),
        ]),
      ],
    );
  }

  static pw.Page _matricCertificate(
    DocumentHolder holder,
    CredentialItem credential,
    Map<String, dynamic>? record,
    String reference,
  ) {
    final year = _value(record, 'year', fallback: credential.qualification?.year?.toString() ?? 'Not on record');
    final result = _value(record, 'overall_pass_status', fallback: credential.qualification?.result ?? 'Not on record');
    final serif = pw.Font.times();
    final serifBold = pw.Font.timesBold();
    final serifItalic = pw.Font.timesItalic();

    // NSC subject structure, for layout only. UbuntuID stores the overall
    // result, not per-subject marks, so no achievement level is invented.
    const subjects = [
      'Home Language',
      'First Additional Language',
      'Mathematics / Mathematical Literacy',
      'Life Orientation',
      'Elective subject 1',
      'Elective subject 2',
      'Elective subject 3',
    ];

    return _page(
      headline: 'DEMONSTRATION / PROTOTYPE CERTIFICATE - NOT A REAL GOVERNMENT-ISSUED CERTIFICATE',
      watermark: 'UBUNTUID DEMONSTRATION\nNOT A REAL CERTIFICATE',
      reference: reference,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _gold, width: 2)),
          child: pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(24, 18, 24, 18),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _greenDark, width: 0.8)),
            child: pw.Column(
              children: [
                _text(
                  'UBUNTUID PROTOTYPE',
                  style: pw.TextStyle(fontSize: 8, color: _green, letterSpacing: 2, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                _text(
                  'National Senior Certificate',
                  style: pw.TextStyle(font: serifBold, fontSize: 26, color: _greenDark),
                  align: pw.TextAlign.center,
                ),
                _text(
                  'Demonstration certificate - simulated Basic Education record',
                  style: pw.TextStyle(font: serifItalic, fontSize: 10, color: _muted),
                ),
                pw.SizedBox(height: 18),
                _text('This is to certify that', style: pw.TextStyle(font: serif, fontSize: 12)),
                pw.SizedBox(height: 6),
                _text(
                  holder.fullName.toUpperCase(),
                  style: pw.TextStyle(font: serifBold, fontSize: 20, letterSpacing: 1),
                ),
                pw.SizedBox(height: 2),
                _text(
                  'Identity number ${holder.groupedIdNumber}',
                  style: pw.TextStyle(font: serif, fontSize: 10, color: _muted),
                ),
                pw.SizedBox(height: 10),
                _text(
                  'is recorded in UbuntuID as having written the National Senior Certificate examination in',
                  style: pw.TextStyle(font: serif, fontSize: 12),
                  align: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                _text(year, style: pw.TextStyle(font: serifBold, fontSize: 16)),
                pw.SizedBox(height: 8),
                _text('with the overall result', style: pw.TextStyle(font: serif, fontSize: 12)),
                pw.SizedBox(height: 4),
                _text(
                  result.toUpperCase(),
                  style: pw.TextStyle(font: serifBold, fontSize: 18, color: _greenDark, letterSpacing: 1),
                ),
                pw.SizedBox(height: 14),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _field('Examination number (UbuntuID ref)', _value(record, 'matric_exam_number')),
                    ),
                    pw.Expanded(child: _field('Date of birth', _card(holder.dateOfBirth))),
                    holder.avatar.build(width: 52, height: 65),
                  ],
                ),
              ],
            ),
          ),
        ),
        _sectionTitle('Subjects and achievement levels'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {0: pw.FlexColumnWidth(4), 1: pw.FlexColumnWidth(2)},
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                for (final h in ['Subject', 'Achievement level'])
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: _text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
              ],
            ),
            for (final s in subjects)
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: _text(s, style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: _text('Not recorded', style: const pw.TextStyle(fontSize: 9, color: _muted)),
                  ),
                ],
              ),
          ],
        ),
        _note(
          'UbuntuID stores the overall NSC result only, so subject rows show the usual certificate structure '
          'without inventing marks. No signature, seal or official insignia is reproduced.',
        ),
      ],
    );
  }

  static pw.Page _tertiary(DocumentHolder holder, CredentialItem credential, String reference) {
    final q = credential.qualification;
    final serifBold = pw.Font.timesBold();
    final serif = pw.Font.times();
    return _page(
      headline: 'DEMONSTRATION / PROTOTYPE - NOT A REAL ACADEMIC RECORD',
      watermark: 'UBUNTUID DEMONSTRATION\nNOT A REAL ACADEMIC RECORD',
      reference: reference,
      children: [
        _docHeader(
          title: 'Statement of Academic Record',
          authority: credential.issuingDepartment,
          subtitle: q?.institutionName == null ? null : 'Institution: ${q!.institutionName}',
        ),
        pw.SizedBox(height: 16),
        _holderPanel(holder),
        pw.SizedBox(height: 18),
        pw.Center(
          child: pw.Column(
            children: [
              _text(
                'Qualification',
                style: pw.TextStyle(font: serif, fontSize: 11, color: _muted),
              ),
              pw.SizedBox(height: 4),
              _text(
                q?.qualificationName ?? credential.typeName,
                style: pw.TextStyle(font: serifBold, fontSize: 18),
                align: pw.TextAlign.center,
              ),
            ],
          ),
        ),
        _sectionTitle('Academic record summary'),
        _detailsTable([
          ('Institution', q?.institutionName ?? 'Not on record'),
          ('Qualification', q?.qualificationName ?? 'Not on record'),
          ('Year', q?.year?.toString() ?? 'Not on record'),
          ('Result / completion status', q?.result ?? 'Not on record'),
          ('Credential status', _status(credential.status)),
          ('Recorded on UbuntuID', _long(credential.issuedDate)),
        ]),
        _note('Module-level results are not stored in UbuntuID; only the qualification outcome is shown.'),
      ],
    );
  }

  static pw.Page _taxCompliance(
    DocumentHolder holder,
    CredentialItem credential,
    Map<String, dynamic>? record,
    String reference,
  ) {
    final compliance = _value(record, 'compliance_status', fallback: _status(credential.status));
    final compliant = compliance.toLowerCase() == 'compliant' || (record == null && credential.status == 'active');
    return _page(
      headline: 'DEMONSTRATION / PROTOTYPE - NOT A REAL TAX COMPLIANCE STATUS',
      watermark: 'UBUNTUID DEMONSTRATION\nNOT A REAL TAX DOCUMENT',
      reference: reference,
      children: [
        _docHeader(title: 'Tax Compliance Status', authority: credential.issuingDepartment),
        pw.SizedBox(height: 16),
        _holderPanel(holder),
        pw.SizedBox(height: 16),
        _statusBox(heading: 'Tax compliance status', status: compliance, positive: compliant),
        _sectionTitle('Taxpayer particulars'),
        _detailsTable([
          ('Taxpayer name', holder.fullName),
          ('Income tax reference (UbuntuID ref)', _value(record, 'tax_number')),
          ('Registered for tax', _long(_date(record, 'registered_date'))),
          ('Status as at', _long(DateTime.now())),
        ]),
        _note(
          'A real compliance status is confirmed online with a verification PIN; this prototype has no PIN '
          'and cannot be used to confirm anyone\'s tax affairs.',
        ),
      ],
    );
  }

  static pw.Page _policeClearance(
    DocumentHolder holder,
    CredentialItem credential,
    Map<String, dynamic>? record,
    String reference,
  ) {
    final status = _value(
      record,
      'status',
      fallback: credential.status == 'active' ? 'Clear' : _status(credential.status),
    );
    final clear = status.toLowerCase() == 'clear';
    return _page(
      headline: 'DEMONSTRATION / PROTOTYPE - NOT A REAL POLICE CLEARANCE CERTIFICATE',
      watermark: 'UBUNTUID DEMONSTRATION\nNOT A REAL CLEARANCE',
      reference: reference,
      children: [
        _docHeader(title: 'Police Clearance Certificate', authority: credential.issuingDepartment),
        pw.SizedBox(height: 16),
        _holderPanel(holder),
        pw.SizedBox(height: 16),
        _statusBox(
          heading: 'Result of criminal record search',
          status: clear ? 'No criminal record' : 'Record on file',
          positive: clear,
        ),
        _sectionTitle('Certificate particulars'),
        _detailsTable([
          ('Applicant', holder.fullName),
          ('Identity number', holder.groupedIdNumber),
          ('Date of issue', _long(_date(record, 'issue_date') ?? credential.issuedDate)),
          ('Recorded status', status),
        ]),
        _note(
          'Real clearance certificates are based on fingerprint verification. UbuntuID simulates the outcome only.',
        ),
      ],
    );
  }

  static pw.Page _employmentLetter(
    DocumentHolder holder,
    CredentialItem credential,
    Map<String, dynamic>? record,
    String reference,
  ) {
    final contribution = record?['uif_contribution_amount'];
    return _page(
      headline: 'DEMONSTRATION / PROTOTYPE - NOT A REAL EMPLOYMENT / UIF RECORD',
      watermark: 'UBUNTUID DEMONSTRATION\nNOT A REAL UIF RECORD',
      reference: reference,
      children: [
        _docHeader(title: 'Employment & UIF Status Confirmation', authority: credential.issuingDepartment),
        pw.SizedBox(height: 16),
        _holderPanel(holder),
        _sectionTitle('Employment record'),
        _detailsTable([
          ('Employer', _value(record, 'employer_name')),
          ('Employment status', _value(record, 'employment_status')),
          ('Start date', _long(_date(record, 'start_date'))),
        ]),
        _sectionTitle('Unemployment Insurance Fund (UIF)'),
        _detailsTable([
          ('Monthly UIF contribution', contribution == null ? 'Not on record' : 'R $contribution'),
          ('UIF claim status', _value(record, 'uif_claim_status')),
          ('Credential status', _status(credential.status)),
        ]),
        _note('Confirms the simulated Employment and Labour record held in UbuntuID on ${_long(DateTime.now())}.'),
      ],
    );
  }

  static pw.Page _grantLetter(
    DocumentHolder holder,
    CredentialItem credential,
    Map<String, dynamic>? record,
    String reference,
  ) {
    final status = _value(record, 'status', fallback: _status(credential.status));
    return _page(
      headline: 'DEMONSTRATION / PROTOTYPE - NOT A REAL SASSA GRANT LETTER',
      watermark: 'UBUNTUID DEMONSTRATION\nNOT A REAL GRANT LETTER',
      reference: reference,
      children: [
        _docHeader(title: 'Social Grant Status Letter', authority: credential.issuingDepartment),
        pw.SizedBox(height: 16),
        _text('Dear ${holder.fullName},', style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 6),
        _text(
          'This letter sets out the social grant recorded against your identity number in the UbuntuID prototype.',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 14),
        _holderPanel(holder),
        pw.SizedBox(height: 16),
        _statusBox(heading: 'Grant status', status: status, positive: status.toLowerCase() == 'active'),
        _sectionTitle('Grant details'),
        _detailsTable([
          ('Grant type', _value(record, 'grant_type')),
          ('Payout method', _value(record, 'payout_method')),
          ('Recorded on', _long(_date(record, 'created_at') ?? credential.issuedDate)),
        ]),
        _note('SASSA data in UbuntuID is simulated. No payment information is held or shown.'),
      ],
    );
  }

  static pw.Page _generic(DocumentHolder holder, CredentialItem credential, String reference) {
    return _page(
      headline: 'DEMONSTRATION / PROTOTYPE DOCUMENT - NOT A REAL GOVERNMENT-ISSUED DOCUMENT',
      watermark: 'UBUNTUID DEMONSTRATION\nNOT A REAL DOCUMENT',
      reference: reference,
      children: [
        _docHeader(title: credential.typeName, authority: credential.issuingDepartment),
        pw.SizedBox(height: 16),
        _holderPanel(holder),
        _sectionTitle('Credential details'),
        _detailsTable([
          ('Credential', credential.typeName),
          ('Status', _status(credential.status)),
          ('Issued', _long(credential.issuedDate)),
          ('Expires', credential.expiryDate == null ? 'No expiry' : _long(credential.expiryDate)),
        ]),
      ],
    );
  }

  /// A published NSC Statement of Results: learner details, every subject
  /// with its percentage and achievement level, and the approved pass
  /// category. Marked as an UbuntuID record summary -- not a certified DBE or
  /// Umalusi document. The QR code carries only the verification link (a
  /// random statement reference), never personal details.
  static Future<Uint8List> nscStatement(DocumentHolder holder, NscStatement statement, String verifyLink) async {
    final doc = pw.Document(title: 'NSC Statement of Results ${statement.examYear}', author: 'UbuntuID');
    final reference = statement.recordReference;

    pw.Widget cell(String text, {bool header = false, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: _text(
            text,
            align: align,
            style: header
                ? pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _greenDark)
                : const pw.TextStyle(fontSize: 9.5),
          ),
        );

    doc.addPage(
      _page(
        headline: 'UBUNTUID RECORD SUMMARY - NOT AN OFFICIALLY CERTIFIED DBE OR UMALUSI DOCUMENT',
        watermark: 'UBUNTUID RECORD SUMMARY\nNOT A CERTIFIED DOCUMENT',
        reference: reference,
        children: [
          _docHeader(
            title: 'Statement of Results',
            authority: 'Department of Basic Education',
            subtitle: 'National Senior Certificate - ${statement.examYear} examination',
          ),
          _sectionTitle('Learner information'),
          _detailsTable([
            ('Full name', statement.learnerName.isEmpty ? holder.fullName : statement.learnerName),
            ('Identity number', holder.groupedIdNumber),
            ('Examination number', statement.examNumber),
            ('Examination year', '${statement.examYear}'),
            if (statement.examSession != null) ('Examination session', statement.examSession!),
            if (statement.schoolName != null) ('School', statement.schoolName!),
          ]),
          _sectionTitle('Examination results'),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {0: pw.FlexColumnWidth(5), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(2.4)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  cell('Subject', header: true),
                  cell('Percentage', header: true, align: pw.TextAlign.center),
                  cell('Achievement level', header: true, align: pw.TextAlign.center),
                ],
              ),
              for (final subject in statement.subjects)
                pw.TableRow(
                  children: [
                    cell(subject.subject),
                    cell(subject.percentageLabel, align: pw.TextAlign.center),
                    cell(subject.achievementLevel?.toString() ?? '-', align: pw.TextAlign.center),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 14),
          _statusBox(heading: 'Overall result', status: statement.passCategory, positive: statement.achieved),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _detailsTable([
                  ('Published', _long(statement.publishedAt)),
                  ('Record reference', reference),
                  ('Record source', 'Department of Basic Education examination results, via UbuntuID'),
                ]),
              ),
              pw.SizedBox(width: 14),
              pw.Column(
                children: [
                  pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: verifyLink, width: 72, height: 72),
                  pw.SizedBox(height: 3),
                  _text('Scan to verify', style: const pw.TextStyle(fontSize: 7, color: _muted)),
                ],
              ),
            ],
          ),
          _note(
            'Achievement levels: 7 (80-100%), 6 (70-79%), 5 (60-69%), 4 (50-59%), 3 (40-49%), 2 (30-39%), '
            '1 (0-29%). This summary was generated by UbuntuID from published examination results and is not '
            'a certified National Senior Certificate.',
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> share(Uint8List bytes, String filename) => Printing.sharePdf(bytes: bytes, filename: filename);

  /// e.g. Kopano_Mogadile_ID.pdf
  static String identityFileName(String firstNames, String surname) =>
      downloadFileName([...personFileNameParts(firstNames, surname), 'ID'], 'pdf');

  /// e.g. Kopano_Mogadile_NSC_Statement_of_Results_2021.pdf
  static String nscStatementFileName(String firstNames, String surname, int year) =>
      downloadFileName([...personFileNameParts(firstNames, surname), 'NSC Statement of Results', '$year'], 'pdf');

  /// e.g. Kopano_Mogadile_Drivers_Licence.pdf
  static String credentialFileName(String firstNames, String surname, String typeName) =>
      downloadFileName([...personFileNameParts(firstNames, surname), typeName], 'pdf');
}
