import 'package:digital_id/features/organisation/domain/bulk_applicants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const licence = BulkCredential(credentialTypeId: 'lic', typeCode: 'DRIVERS_LICENCE', displayName: "Driver's Licence");
  const passport = BulkCredential(credentialTypeId: 'pp', typeCode: 'PASSPORT', displayName: 'Passport');
  const creds = [licence, passport];

  // Valid Luhn SA IDs.
  const id1 = '8001015009087';
  const id2 = '9202204720083';

  test('validates SA ID checksum and restores a dropped leading zero', () {
    expect(isValidSaId(id1), isTrue);
    expect(isValidSaId('8001015009088'), isFalse);
    expect(cleanIdNumber('800101 5009 087'), id1);
    expect(cleanIdNumber('101015009087'), '0101015009087');
  });

  test('reads the template headers and forgiving dropdown values', () {
    final headers = templateHeaders(creds);
    final result = parseApplicants([
      headers,
      [id1, 'Kopano', 'Mogadile', 'b', 'valid', ''],
    ], creds);

    final row = result.rows.single;
    expect(row.status, BulkRowStatus.ready);
    expect(row.claims['lic'], {'licence_code': 'Code B', 'status': 'Valid'});
    expect(row.claims.containsKey('pp'), isFalse, reason: 'blank passport columns skip that check');
  });

  test('accepts alias headers and flags invalid values, bad IDs and duplicates', () {
    final result = parseApplicants([
      ['Identity Number', 'Surname', 'Name', "Driver's Licence: licence code", "Driver's Licence: status"],
      [id1, 'Mogadile', 'Kopano', 'Code Z', 'Valid'],
      ['123', 'X', 'Y', 'B', 'Valid'],
      [id2, 'Dlamini', 'Lerato', 'B', ''],
      [id2, 'Dlamini', 'Lerato', 'EB', 'Expired'],
    ], creds);

    expect(result.rows[0].status, BulkRowStatus.missingData);
    expect(result.rows[1].status, BulkRowStatus.invalidId);
    expect(result.rows[2].status, BulkRowStatus.duplicate);
    expect(result.rows[3].status, BulkRowStatus.ready);
  });

  test('lookups: not found, name mismatch, replaces earlier application', () {
    final result = parseApplicants([
      templateHeaders(creds),
      [id1, 'Kopano', 'Mogadile', 'B', 'Valid', ''],
      [id2, 'Thabo', 'Nkosi', 'B', 'Valid', ''],
      ['0101015009083', 'Sipho', 'Khumalo', '', '', 'Active'],
    ], creds);

    applyLookups(
      result.rows,
      {
        id1: (citizenId: 'c1', firstName: 'Kopano Isago', lastName: 'Mogadile'),
        id2: (citizenId: 'c2', firstName: 'Lerato', lastName: 'Dlamini'),
      },
      {'c1'},
    );

    expect(result.rows[0].status, BulkRowStatus.replacesEarlier);
    expect(result.rows[0].willSubmit, isTrue);
    expect(result.rows[1].status, BulkRowStatus.nameMismatch);
    expect(result.rows[1].willSubmit, isFalse);
    expect(result.rows[2].status, BulkRowStatus.notFound);
  });

  test('reads the matric year column and marks incomplete rows', () {
    const nsc = BulkCredential(credentialTypeId: 'nsc', typeCode: 'NSC', displayName: 'National Senior Certificate');
    final result = parseApplicants([
      templateHeaders(const [nsc]),
      [id1, 'Kopano', 'Mogadile', 'Diploma', '2016'],
      [id2, 'Lerato', 'Dlamini', 'Diploma', ''],
    ], const [nsc]);

    expect(result.rows[0].status, BulkRowStatus.ready);
    expect(result.rows[0].claims['nsc'], {'overall_pass_status': 'Diploma', 'year': '2016'});
    expect(result.rows[1].status, BulkRowStatus.missingData);
    expect(result.rows[1].status.isIncomplete, isTrue);
  });
}
