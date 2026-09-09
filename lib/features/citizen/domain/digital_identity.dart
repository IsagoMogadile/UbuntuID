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

  String get fullName => '$firstName $lastName';
}
