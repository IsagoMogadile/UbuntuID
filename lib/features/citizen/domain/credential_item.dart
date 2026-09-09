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
    this.qualification,
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

  /// The real record behind an NSC/TERTIARY_QUALIFICATION credential --
  /// institution, qualification name, year, result -- sourced live from
  /// `dbe_nsc_results`/`dhet_academic_records`+`dhet_institutions` rather
  /// than just the generic credential status. `null` for every other
  /// credential type.
  final QualificationDetail? qualification;
}

class QualificationDetail {
  const QualificationDetail({
    required this.qualificationName,
    required this.result,
    this.institutionName,
    this.year,
  });

  final String qualificationName;
  final String? institutionName;
  final String? result;
  final int? year;
}
