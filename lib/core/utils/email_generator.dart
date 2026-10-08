/// Auto-generates an email address for a newly created profile, following
/// the same `firstname.lastname@<domain>` convention across every role.
/// Citizens registered by Home Affairs are the exception: they must give
/// their own real email (`DepartmentRepository.registerCitizen`), since it's
/// what they sign up with to claim their record.
library;

const _citizenDomains = ['gmail.com', 'yahoo.com', 'outlook.com', 'webmail.co.za'];

/// Generic public-domain email for a citizen or a person with no
/// organisational affiliation. [seed] should be a stable per-person value
/// (e.g. an index or hash) so repeated generation for the same person is
/// deterministic; pass a different seed to vary the domain deterministically
/// across a batch.
String generateCitizenEmail({
  required String firstName,
  required String lastName,
  int seed = 0,
}) {
  final domain = _citizenDomains[seed % _citizenDomains.length];
  return '${_slug(firstName)}.${_slug(lastName)}@$domain';
}

/// `firstname.lastname@<departmentCode>.gov.za`, e.g. a Home Affairs
/// official's department code `DHA` becomes `dha.gov.za`.
String generateDepartmentOfficialEmail({
  required String firstName,
  required String lastName,
  required String departmentCode,
}) {
  return '${_slug(firstName)}.${_slug(lastName)}@${_slug(departmentCode)}.gov.za';
}

/// `firstname.lastname@ubuntu.gov.za` for UbuntuID platform administrators.
String generateAdminEmail({
  required String firstName,
  required String lastName,
}) {
  return '${_slug(firstName)}.${_slug(lastName)}@ubuntu.gov.za';
}

/// `firstname.lastname@<organisationDomain>` for an organisation's own
/// users, e.g. `coastaltech.co.za`.
String generateOrganisationUserEmail({
  required String firstName,
  required String lastName,
  required String organisationDomain,
}) {
  return '${_slug(firstName)}.${_slug(lastName)}@$organisationDomain';
}

/// Appends a numeric disambiguator (e.g. `john.smith2@gmail.com`) when the
/// base local-part would collide with an existing email. Callers own the
/// uniqueness check (a DB lookup); this only formats the retry.
String withDisambiguator(String email, int attempt) {
  if (attempt <= 0) return email;
  final at = email.indexOf('@');
  if (at < 0) return email;
  return '${email.substring(0, at)}$attempt${email.substring(at)}';
}

String _slug(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r"['’]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
  return normalized.split(RegExp(r'\s+')).join('');
}
