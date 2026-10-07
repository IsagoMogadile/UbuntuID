import 'dart:io';

import 'package:digital_id/features/citizen/documents/credential_documents.dart';
import 'package:digital_id/features/citizen/domain/credential_item.dart';
import 'package:digital_id/features/citizen/domain/digital_identity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds every prototype document from sample data. Set UBUNTUID_PDF_OUT
/// to a folder to also write the PDFs there for visual review.
void main() {
  final identity = DigitalIdentity(
    citizenId: 'c1',
    idNumber: '9006180123084',
    firstName: 'Lerato Naledi',
    lastName: 'Mokoena',
    dateOfBirth: DateTime(1990, 6, 18),
    currentStatus: 'active',
    registeredAt: DateTime(2026, 3, 2),
    gender: 'female',
    citizenshipStatus: 'citizen',
  );
  final holder = DocumentHolder.fromIdentity(identity, address: '12 Jacaranda Street, Hatfield, Pretoria, Gauteng, 0083');
  final outDir = Platform.environment['UBUNTUID_PDF_OUT'];

  Future<void> save(String name, List<int> bytes) async {
    expect(bytes.length, greaterThan(1000));
    if (outDir != null) await File('$outDir/$name.pdf').writeAsBytes(bytes);
  }

  CredentialItem credential(String code, String name, String department, {QualificationDetail? q}) => CredentialItem(
        credentialId: 'abcdef12-3456-7890',
        typeCode: code,
        typeName: name,
        issuingDepartment: department,
        status: 'active',
        issuedDate: DateTime(2024, 2, 1),
        expiryDate: DateTime(2029, 1, 31),
        qualification: q,
      );

  test('holder falls back to the ID number for sex and citizenship', () {
    final fromId = DocumentHolder.fromIdentity(DigitalIdentity(
      citizenId: 'c2',
      idNumber: '8501015800081',
      firstName: 'Sipho',
      lastName: 'Dlamini',
      dateOfBirth: DateTime(1985),
      currentStatus: 'active',
      registeredAt: DateTime(2026),
    ));
    expect(fromId.feminine, isFalse);
    expect(fromId.citizenshipLabel, 'South African citizen');
    expect(fromId.groupedIdNumber, '850101 5800 08 1');
  });

  test('masculine avatar variant builds', () async {
    final male = DocumentHolder.fromIdentity(DigitalIdentity(
      citizenId: 'c3',
      idNumber: '8501015800081',
      firstName: 'Sipho',
      lastName: 'Dlamini',
      dateOfBirth: DateTime(1985),
      currentStatus: 'active',
      registeredAt: DateTime(2026),
    ));
    await save('identity_document_male', await CredentialDocuments.identityDocument(male));
  });

  test('identity document has front and back pages', () async {
    final bytes = await CredentialDocuments.identityDocument(holder);
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length, 2);
    await save('identity_document', bytes);
  });

  final cases = {
    'drivers_licence': (
      credential('DRIVERS_LICENCE', "Driver's Licence", 'Department of Transport'),
      {'licence_code': 'B', 'licence_number': 'DL-000123', 'issue_date': '2024-02-01', 'expiry_date': '2029-01-31', 'status': 'Valid'},
    ),
    'passport': (
      credential('PASSPORT', 'Passport', 'Department of Home Affairs'),
      {'passport_number': 'P-0004567', 'issue_date': '2023-05-10', 'expiry_date': '2033-05-09', 'status': 'Valid'},
    ),
    'matric': (
      credential('NSC', 'National Senior Certificate', 'Department of Basic Education'),
      {'year': 2008, 'overall_pass_status': 'Bachelor Pass', 'matric_exam_number': 'NSC-2008-001'},
    ),
    'tertiary': (
      credential('TERTIARY_QUALIFICATION', 'Tertiary Qualification', 'Department of Higher Education and Training',
          q: const QualificationDetail(
            qualificationName: 'BSc Computer Science',
            institutionName: 'University of Pretoria',
            result: 'Pass with distinction',
            year: 2012,
          )),
      null,
    ),
    'tax_compliance': (
      credential('TAX_COMPLIANCE', 'Tax Compliance', 'National Treasury (SARS)'),
      {'tax_number': '0123456789', 'compliance_status': 'Compliant', 'registered_date': '2013-03-01'},
    ),
    'police_clearance': (
      credential('CRIMINAL_CLEARANCE', 'Criminal Clearance', 'South African Police Service'),
      {'issue_date': '2025-11-03', 'status': 'Clear'},
    ),
    'employment_uif': (
      credential('LABOUR_STATUS', 'Employment Status', 'Department of Employment and Labour'),
      {'employer_name': 'Karoo Insurance & Employment Group', 'employment_status': 'Employed', 'start_date': '2019-04-01', 'uif_contribution_amount': 177.12, 'uif_claim_status': 'No claim'},
    ),
    'sassa_grant': (
      credential('SASSA_STATUS', 'SASSA Grant', 'SASSA'),
      {'grant_type': 'Child Support Grant', 'status': 'Active', 'payout_method': 'Bank transfer', 'created_at': '2024-07-15T09:00:00Z'},
    ),
    'generic_missing_record': (credential('SOMETHING_NEW', 'Other Credential', 'Department of Home Affairs'), null),
  };

  for (final entry in cases.entries) {
    test('builds ${entry.key}', () async {
      final bytes = await CredentialDocuments.credentialDocument(holder, entry.value.$1, entry.value.$2);
      await save(entry.key, bytes);
    });
  }

  test('a credential whose record is unreadable still builds (shows "Not on record")', () async {
    final bytes = await CredentialDocuments.credentialDocument(
      holder,
      credential('DRIVERS_LICENCE', "Driver's Licence", 'Department of Transport'),
      null,
    );
    await save('drivers_licence_no_record', bytes);
  });
}
