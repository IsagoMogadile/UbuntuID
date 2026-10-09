import 'dart:typed_data';

import '../../citizen/documents/credential_documents.dart';
import '../../citizen/domain/citizen_address.dart';
import '../../citizen/domain/credential_item.dart';
import '../../citizen/domain/digital_identity.dart';

/// The document behind a scanned QR code, as returned by the
/// `public_document` RPC -- the same inputs the citizen's own download uses
/// ([DocumentDownloads]), so a scanned code yields the identical PDF.
class PublicDocument {
  PublicDocument._(this.identity, {this.credential, this.record, this.address});

  factory PublicDocument.fromJson(Map<String, dynamic> json) {
    DateTime? date(Map<String, dynamic>? m, String key) =>
        m?[key] == null ? null : DateTime.tryParse(m![key].toString());
    Map<String, dynamic>? map(Object? value) => value == null ? null : Map<String, dynamic>.from(value as Map);

    final holder = map(json['holder'])!;
    final identity = DigitalIdentity(
      citizenId: holder['citizen_id'] as String,
      idNumber: holder['id_number'] as String? ?? '',
      firstName: holder['first_name'] as String? ?? '',
      lastName: holder['last_name'] as String? ?? '',
      dateOfBirth: date(holder, 'date_of_birth') ?? DateTime(1900),
      currentStatus: holder['current_status'] as String? ?? 'active',
      registeredAt: date(holder, 'registered_at') ?? DateTime.now(),
      gender: holder['gender'] as String?,
      citizenshipStatus: holder['citizenship_status'] as String?,
    );

    final a = map(json['address']);
    final address = a == null
        ? null
        : CitizenAddress(
            addressType: a['address_type'] as String? ?? 'residential',
            isCurrent: a['is_current'] as bool? ?? true,
            unitNumber: a['unit_number'] as String?,
            streetNumber: a['street_number']?.toString(),
            streetName: a['street_name'] as String?,
            suburb: a['suburb'] as String?,
            city: a['city'] as String?,
            municipality: a['municipality'] as String?,
            province: a['province'] as String?,
            postalCode: a['postal_code']?.toString(),
          );

    final c = map(json['credential']);
    final q = map(json['qualification']);
    final credential = c == null
        ? null
        : CredentialItem(
            credentialId: c['credential_id'] as String,
            typeCode: c['type_code'] as String? ?? '',
            typeName: c['display_name'] as String? ?? 'Credential',
            issuingDepartment: c['department'] as String? ?? 'Unknown department',
            status: c['status'] as String? ?? 'pending',
            issuedDate: date(c, 'issued_date') ?? DateTime.now(),
            expiryDate: date(c, 'expiry_date'),
            qualification: q == null
                ? null
                : QualificationDetail(
                    qualificationName: q['qualification_name'] as String? ?? 'Qualification',
                    institutionName: q['institution_name'] as String?,
                    result: q['result'] as String?,
                    year: (q['year'] as num?)?.toInt(),
                  ),
          );

    return PublicDocument._(identity, credential: credential, record: map(json['record']), address: address);
  }

  final DigitalIdentity identity;

  /// Null for the identity card's code, which opens the ID document.
  final CredentialItem? credential;
  final Map<String, dynamic>? record;
  final CitizenAddress? address;

  String get title => credential?.typeName ?? 'Identity Document';

  String get fileName => credential == null
      ? CredentialDocuments.identityFileName(identity.firstName, identity.lastName)
      : CredentialDocuments.credentialFileName(identity.firstName, identity.lastName, credential!.typeName);

  Future<Uint8List> buildPdf() {
    final holder = DocumentHolder.fromIdentity(identity, address: address?.formatted);
    final c = credential;
    return c == null ? CredentialDocuments.identityDocument(holder) : CredentialDocuments.credentialDocument(holder, c, record);
  }
}
