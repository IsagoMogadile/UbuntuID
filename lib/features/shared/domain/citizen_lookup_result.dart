/// Generic citizen identity lookup result -- used by the department-official
/// and administrator "search citizen by ID number" screens (spec §3.2/§3.4:
/// any official/admin can locate a citizen's central identity record).
/// Deliberately identity-only (no department-specific records) since the
/// department-specific record screens are separate features.
class CitizenLookupResult {
  const CitizenLookupResult({
    required this.citizenId,
    required this.firstName,
    required this.lastName,
    required this.idNumber,
    required this.currentStatus,
    this.dateOfBirth,
    this.phoneNumber,
    this.email,
  });

  final String citizenId;
  final String firstName;
  final String lastName;
  final String idNumber;
  final String currentStatus;
  final DateTime? dateOfBirth;
  final String? phoneNumber;
  final String? email;

  String get fullName => '$firstName $lastName'.trim();
}
