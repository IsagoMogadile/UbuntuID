import 'package:digital_id/features/verification/data/public_verification_repository.dart';
import 'package:digital_id/features/verification/domain/public_document.dart';
import 'package:digital_id/features/verification/domain/public_verification_result.dart';
import 'package:digital_id/features/verification/presentation/public_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ref = '3f2b8c1e-5a7d-4e2f-9b1c-0d6e8a4f2c71';

/// The document itself is stubbed out (null) in widget tests -- rendering a
/// real PdfPreview needs a platform rasteriser. buildPdf() is covered below.
Future<void> _pump(WidgetTester tester, Future<PublicVerificationResult?> Function() lookup) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        publicVerificationProvider(_ref).overrideWith((ref) => lookup()),
        publicDocumentProvider(_ref).overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: PublicVerificationScreen(docRef: _ref)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Shape of a `public_document` RPC response for a UIF (LABOUR_STATUS) card.
final _uifPayload = <String, dynamic>{
  'kind': 'credential',
  'holder': {
    'citizen_id': 'a1b2c3d4-0000-4000-8000-000000000001',
    'id_number': '9006185086084',
    'first_name': 'Thabo',
    'last_name': 'Nkosi',
    'date_of_birth': '1990-06-18',
    'gender': 'Male',
    'citizenship_status': 'citizen',
    'current_status': 'active',
    'registered_at': '2024-02-01T09:30:00+00:00',
  },
  'address': null,
  'credential': {
    'credential_id': _ref,
    'type_code': 'LABOUR_STATUS',
    'display_name': 'UIF Status',
    'department': 'Department of Employment and Labour',
    'status': 'active',
    'issued_date': '2023-03-01',
    'expiry_date': null,
  },
  'record': {'employer_name': 'Acme Logistics', 'employment_status': 'employed', 'start_date': '2023-03-01'},
  'qualification': null,
};

void main() {
  // The PDF loads the coat of arms from the asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses the status payload', () {
    final r = PublicVerificationResult.fromJson({
      'kind': 'credential',
      'document': 'Passport',
      'issuer': 'Department of Home Affairs',
      'status': 'active',
      'issued_date': '2024-01-15',
      'expiry_date': '2034-01-14',
    });
    expect(r.isIdentity, isFalse);
    expect(r.isValid, isTrue);
    expect(r.expiryDate, DateTime(2034, 1, 14));
  });

  test('a scanned UIF code builds the UIF status PDF', () async {
    final document = PublicDocument.fromJson(_uifPayload);
    expect(document.credential?.typeCode, 'LABOUR_STATUS');
    expect(document.fileName, 'Thabo_Nkosi_UIF_Status.pdf');
    final bytes = await document.buildPdf();
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('a scanned identity code builds the ID document', () async {
    final document = PublicDocument.fromJson({
      ..._uifPayload,
      'kind': 'identity',
      'credential': null,
      'record': null,
      'address': {'address_type': 'residential', 'is_current': true, 'street_name': 'Main Road', 'city': 'Gqeberha'},
    });
    expect(document.credential, isNull);
    expect(document.address?.formatted, 'Main Road, Gqeberha');
    expect(String.fromCharCodes((await document.buildPdf()).take(5)), '%PDF-');
  });

  testWidgets('a current credential reads as valid', (tester) async {
    await _pump(
      tester,
      () async => const PublicVerificationResult(
        isIdentity: false,
        document: 'UIF Status',
        issuer: 'Department of Employment and Labour',
        status: 'active',
      ),
    );
    expect(find.text('Valid document'), findsOneWidget);
    expect(find.text('UIF Status · Department of Employment and Labour'), findsOneWidget);
  });

  testWidgets('an expired credential reads as not valid', (tester) async {
    await _pump(
      tester,
      () async => const PublicVerificationResult(
        isIdentity: false,
        document: "Driver's Licence",
        issuer: 'Department of Transport',
        status: 'expired',
      ),
    );
    expect(find.text('Not valid'), findsOneWidget);
  });

  testWidgets('an unknown code is not recognised', (tester) async {
    await _pump(tester, () async => null);
    expect(find.text('Not recognised'), findsOneWidget);
  });

  testWidgets('a failed lookup says the check is unavailable', (tester) async {
    await _pump(tester, () => Future.error(Exception('function not found')));
    expect(find.text('Check unavailable'), findsOneWidget);
  });
}
