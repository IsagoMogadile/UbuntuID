/// Mirrors `public.citizens`.
class DigitalIdentity {
  const DigitalIdentity({
    required this.citizenId,
    required this.idNumber,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.currentStatus,
    required this.registeredAt,
    this.phoneNumber,
    this.email,
    this.gender,
    this.citizenshipStatus,
  });

  final String citizenId;
  final String idNumber;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String currentStatus;
  final DateTime registeredAt;
  final String? phoneNumber;
  final String? email;

  /// `citizens.gender` / `citizens.citizenship_status` -- used on the
  /// downloadable identity document. Either may be null on older rows.
  final String? gender;
  final String? citizenshipStatus;

  String get fullName => '$firstName $lastName';
}
