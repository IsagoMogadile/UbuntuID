/// Everything an administrator needs to decide on an organisation's
/// application: who they are, who registered it, what they want to verify
/// and why, and earlier review decisions.
class OrganisationReviewDetail {
  const OrganisationReviewDetail({
    required this.registrationNumber,
    required this.contactPhone,
    required this.accessPurpose,
    required this.requestedAt,
    required this.reviewedAt,
    required this.scopes,
    required this.staff,
    required this.history,
  });

  final String? registrationNumber;
  final String? contactPhone;
  final String? accessPurpose;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;
  final List<({String name, String department, String? reason})> scopes;
  final List<({String name, String role, String? email, String? idNumber, bool active})> staff;
  final List<({String status, String? notes, DateTime? at})> history;
}
