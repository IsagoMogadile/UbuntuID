import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'verification_claim_config.dart';

/// Bulk applicant upload (organisation "New Applicant" > Upload): reads an
/// Excel/CSV file, maps its columns, checks every row and produces a
/// preview. Every applicant is checked against the organisation's approved
/// credentials (chosen at registration); a credential whose columns are
/// left blank in a row is simply not checked for that applicant.
/// Submission itself is in BulkUploadScreen via `org_submit_application`
/// (docs/database/bulk_applications_and_employment_terms.sql).

class BulkCredential {
  const BulkCredential({required this.credentialTypeId, required this.typeCode, required this.displayName});

  final String credentialTypeId;
  final String typeCode;
  final String displayName;

  List<ClaimField> get fields => claimFieldsForType(typeCode);
}

enum BulkRowStatus {
  ready('Ready'),
  replacesEarlier('Ready - replaces earlier application'),
  nameMismatch("Name doesn't match ID"),
  notFound('Not found'),
  invalidId('Invalid ID number'),
  missingData('Missing or invalid details'),
  duplicate('Duplicate in file'),
  noCredentials('No credentials filled in');

  const BulkRowStatus(this.label);
  final String label;

  bool get isReady => this == ready || this == replacesEarlier;
}

class BulkRow {
  BulkRow({
    required this.rowNumber,
    required this.idNumber,
    required this.firstName,
    required this.lastName,
    required this.claims,
    required this.issues,
  });

  /// 1-based spreadsheet row, header included -- what the user sees in Excel.
  final int rowNumber;
  final String idNumber;
  final String firstName;
  final String lastName;

  /// credentialTypeId -> (field key -> canonical value), only for
  /// credentials filled in on this row.
  final Map<String, Map<String, String>> claims;
  final List<String> issues;

  String? citizenId;
  String? registeredName;
  BulkRowStatus status = BulkRowStatus.ready;

  /// The user chose to submit a name-mismatch row anyway.
  bool includeAnyway = false;
  bool removed = false;

  String get displayName {
    if (registeredName != null && registeredName!.isNotEmpty) return registeredName!;
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? (idNumber.isEmpty ? 'Row $rowNumber' : idNumber) : name;
  }

  bool get willSubmit => !removed && citizenId != null && (status.isReady || (status == BulkRowStatus.nameMismatch && includeAnyway));
}

class BulkParseResult {
  const BulkParseResult({required this.rows, required this.recognisedColumns, required this.ignoredColumns});

  final List<BulkRow> rows;
  final List<String> recognisedColumns;
  final List<String> ignoredColumns;
}

/// Lower-case letters and digits only, minus a leading "code" -- the same
/// forgiving comparison the database uses (`_normalise_claim_value`).
String normaliseValue(String value) {
  var v = value.toLowerCase().trim();
  v = v.replaceFirst(RegExp(r'^code\s+'), '');
  return v.replaceAll(RegExp('[^a-z0-9]'), '');
}

String _normaliseHeader(String value) => value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

const _idAliases = {'idnumber', 'id', 'idno', 'identitynumber', 'identityno', 'said', 'saidnumber', 'nationalid', 'nationalidnumber'};
const _firstNameAliases = {'firstname', 'name', 'firstnames', 'givenname', 'givennames', 'forename', 'forenames'};
const _lastNameAliases = {'lastname', 'surname', 'familyname'};

String claimHeader(BulkCredential credential, ClaimField field) =>
    '${credential.displayName}: ${field.label.replaceFirst(RegExp(r'^Claimed\s+'), '')}';

List<String> templateHeaders(List<BulkCredential> credentials) => [
      'ID number',
      'First name',
      'Last name',
      for (final c in credentials)
        for (final f in c.fields) claimHeader(c, f),
    ];

/// Builds the downloadable .xlsx template: an "Applicants" sheet with the
/// headers, and an "Allowed values" sheet listing each pick-list column's
/// options.
Uint8List buildTemplate(List<BulkCredential> credentials) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
  excel.rename(defaultSheet, 'Applicants');
  final sheet = excel['Applicants'];
  sheet.appendRow([for (final h in templateHeaders(credentials)) TextCellValue(h)]);

  final allowed = excel['Allowed values'];
  allowed.appendRow([TextCellValue('Column'), TextCellValue('Allowed values')]);
  allowed.appendRow([TextCellValue('ID number'), TextCellValue('13-digit South African ID number')]);
  for (final c in credentials) {
    for (final f in c.fields) {
      final values = f.type == ClaimFieldType.dropdown ? (f.options ?? const []).join(', ') : 'Free text';
      allowed.appendRow([TextCellValue(claimHeader(c, f)), TextCellValue(values)]);
    }
  }
  allowed.appendRow([TextCellValue('')]);
  allowed.appendRow([TextCellValue('Leave all of a credential\'s columns blank to skip that check for an applicant.')]);
  excel.setDefaultSheet('Applicants');
  return Uint8List.fromList(excel.encode()!);
}

/// Reads the first sheet of an .xlsx, or a .csv, into rows of trimmed strings.
List<List<String>> readTable(Uint8List bytes, String fileName) {
  if (fileName.toLowerCase().endsWith('.csv')) return _parseCsv(String.fromCharCodes(bytes));

  final excel = Excel.decodeBytes(bytes);
  final sheetName = excel.tables.containsKey('Applicants') ? 'Applicants' : excel.tables.keys.first;
  final table = excel.tables[sheetName]!;
  return [
    for (final row in table.rows) [for (final cell in row) _cellText(cell?.value)],
  ];
}

String _cellText(CellValue? value) => switch (value) {
      null => '',
      TextCellValue(:final value) => _spanText(value).trim(),
      IntCellValue(:final value) => '$value',
      DoubleCellValue(:final value) =>
        value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString(),
      DateCellValue() => value.asDateTimeLocal().toIso8601String().split('T').first,
      _ => value.toString().trim(),
    };

String _spanText(TextSpan span) =>
    '${span.text ?? ''}${(span.children ?? const <TextSpan>[]).map(_spanText).join()}';

List<List<String>> _parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  final src = text.startsWith('﻿') ? text.substring(1) : text;
  for (var i = 0; i < src.length; i++) {
    final ch = src[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < src.length && src[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',' || ch == ';') {
      row.add(cell.toString().trim());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < src.length && src[i + 1] == '\n') i++;
      row.add(cell.toString().trim());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString().trim());
    rows.add(row);
  }
  return rows;
}

/// South African ID: 13 digits with a valid Luhn check digit.
bool isValidSaId(String id) {
  if (!RegExp(r'^\d{13}$').hasMatch(id)) return false;
  var sum = 0;
  for (var i = 0; i < 13; i++) {
    var d = int.parse(id[12 - i]);
    if (i.isOdd) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 == 0;
}

/// Excel drops leading zeros from numeric IDs (people born 2000-2009), and
/// people type spaces/dashes -- restore a clean 13-digit string.
String cleanIdNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12) return '0$digits';
  return digits;
}

/// Maps headers to columns, then checks each data row on its own (no
/// database): ID format, duplicates, names present, claim values valid.
/// Citizen lookups happen afterwards in [applyLookups].
BulkParseResult parseApplicants(List<List<String>> table, List<BulkCredential> credentials) {
  if (table.isEmpty) return const BulkParseResult(rows: [], recognisedColumns: [], ignoredColumns: []);

  final headers = table.first;
  int? idCol, firstCol, lastCol;
  final claimCols = <(BulkCredential, ClaimField), int>{};
  final recognised = <String>[];
  final ignored = <String>[];

  final claimHeaderLookup = <String, (BulkCredential, ClaimField)>{};
  for (final c in credentials) {
    for (final f in c.fields) {
      claimHeaderLookup[_normaliseHeader(claimHeader(c, f))] = (c, f);
      claimHeaderLookup[_normaliseHeader('${c.typeCode} ${f.key}')] = (c, f);
    }
  }

  for (var i = 0; i < headers.length; i++) {
    final raw = headers[i];
    final h = _normaliseHeader(raw);
    if (h.isEmpty) continue;
    if (idCol == null && _idAliases.contains(h)) {
      idCol = i;
    } else if (firstCol == null && _firstNameAliases.contains(h)) {
      firstCol = i;
    } else if (lastCol == null && _lastNameAliases.contains(h)) {
      lastCol = i;
    } else if (claimHeaderLookup.containsKey(h) && !claimCols.containsKey(claimHeaderLookup[h])) {
      claimCols[claimHeaderLookup[h]!] = i;
    } else {
      ignored.add(raw);
      continue;
    }
    recognised.add(raw);
  }

  if (idCol == null) {
    throw const FormatException('No "ID number" column found. Download the template to see the expected columns.');
  }

  String at(List<String> row, int? col) => (col != null && col < row.length) ? row[col].trim() : '';

  final rows = <BulkRow>[];
  final seenIds = <String, BulkRow>{};
  for (var r = 1; r < table.length; r++) {
    final cells = table[r];
    if (cells.every((c) => c.trim().isEmpty)) continue;

    final issues = <String>[];
    final claims = <String, Map<String, String>>{};
    for (final c in credentials) {
      final values = <String, String>{};
      final missing = <String>[];
      for (final f in c.fields) {
        final col = claimCols[(c, f)];
        final value = at(cells, col);
        if (value.isEmpty) {
          missing.add(f.label);
          continue;
        }
        if (f.type == ClaimFieldType.dropdown) {
          final match = (f.options ?? const []).where((o) => normaliseValue(o) == normaliseValue(value));
          if (match.isEmpty) {
            issues.add('${claimHeader(c, f)}: "$value" is not one of ${(f.options ?? const []).join(', ')}');
          } else {
            values[f.key] = match.first;
          }
        } else {
          values[f.key] = value;
        }
      }
      if (values.isEmpty && missing.length == c.fields.length) continue; // credential skipped
      if (missing.isNotEmpty) {
        issues.add('${c.displayName}: missing ${missing.map((m) => m.replaceFirst(RegExp(r'^Claimed\s+'), '')).join(', ')}');
      }
      claims[c.credentialTypeId] = values;
    }

    final row = BulkRow(
      rowNumber: r + 1,
      idNumber: cleanIdNumber(at(cells, idCol)),
      firstName: at(cells, firstCol),
      lastName: at(cells, lastCol),
      claims: claims,
      issues: issues,
    );

    // Only the shape is enforced here; a failed checksum is just a typo
    // hint if the ID isn't found (a few real records don't pass it).
    if (!RegExp(r'^\d{13}$').hasMatch(row.idNumber)) {
      row.status = BulkRowStatus.invalidId;
      row.issues.insert(0, '"${at(cells, idCol)}" is not a 13-digit SA ID number');
    } else if (row.firstName.isEmpty && row.lastName.isEmpty) {
      row.status = BulkRowStatus.missingData;
      row.issues.insert(0, 'First name and last name are missing');
    } else if (issues.isNotEmpty) {
      row.status = BulkRowStatus.missingData;
    } else if (claims.isEmpty) {
      row.status = BulkRowStatus.noCredentials;
      row.issues.add('Fill in at least one credential\'s columns');
    }

    // Same person twice in one file: the later row wins, as with
    // re-applying (the new application replaces the old one).
    final earlier = seenIds[row.idNumber];
    if (earlier != null && row.status != BulkRowStatus.invalidId) {
      earlier.status = BulkRowStatus.duplicate;
      earlier.issues.add('Replaced by row ${row.rowNumber} for the same ID number');
    }
    if (row.status != BulkRowStatus.invalidId) seenIds[row.idNumber] = row;
    rows.add(row);
  }

  return BulkParseResult(rows: rows, recognisedColumns: recognised, ignoredColumns: ignored);
}

String _normaliseName(String value) => value.toLowerCase().replaceAll(RegExp('[^a-z]'), '');

bool _namePartMatches(String fromFile, String registered) {
  final a = _normaliseName(fromFile);
  if (a.isEmpty) return true;
  final b = _normaliseName(registered);
  return b.contains(a) || a.contains(b);
}

/// Applies the citizen lookups: [citizensById] maps ID number ->
/// (citizenId, first name, last name); [citizenIdsWithOpenApplications]
/// are citizens this organisation already has an application for.
void applyLookups(
  List<BulkRow> rows,
  Map<String, ({String citizenId, String firstName, String lastName})> citizensById,
  Set<String> citizenIdsWithOpenApplications,
) {
  for (final row in rows) {
    if (row.status == BulkRowStatus.invalidId || row.status == BulkRowStatus.duplicate) continue;
    final citizen = citizensById[row.idNumber];
    if (citizen == null) {
      row.status = BulkRowStatus.notFound;
      row.issues.insert(
        0,
        isValidSaId(row.idNumber)
            ? 'No citizen is registered with ID number ${row.idNumber}'
            : 'No citizen is registered with ID number ${row.idNumber} - its check digit is wrong, so it is probably mistyped',
      );
      continue;
    }
    row.citizenId = citizen.citizenId;
    row.registeredName = '${citizen.firstName} ${citizen.lastName}'.trim();
    if (row.status != BulkRowStatus.ready) continue;

    if (!_namePartMatches(row.firstName, citizen.firstName) || !_namePartMatches(row.lastName, citizen.lastName)) {
      row.status = BulkRowStatus.nameMismatch;
      row.issues.insert(0, 'File says "${row.firstName} ${row.lastName}" but ID ${row.idNumber} belongs to ${row.registeredName}');
    } else if (citizenIdsWithOpenApplications.contains(citizen.citizenId)) {
      row.status = BulkRowStatus.replacesEarlier;
    }
  }
}
