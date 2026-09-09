/// Mirrors `public.credentials` joined with `public.credential_types`.
class CredentialItem {
  const CredentialItem({
    required this.credentialId,
    required this.typeName,
    required this.issuingDepartment,
    required this.status,
    required this.issuedDate,
    this.expiryDate,
    this.nqfLevel,
  });

  final String credentialId;
  final String typeName;
  final String issuingDepartment;
  final String status;
  final DateTime issuedDate;
  final DateTime? expiryDate;

  /// NQF level (4 = matric/National Senior Certificate, 5-9 = post-school
  /// qualifications), read from the `qualifications` subtype table. `null`
  /// when this credential has no matching `qualifications` row (i.e. isn't
  /// an education credential).
  final int? nqfLevel;
}
