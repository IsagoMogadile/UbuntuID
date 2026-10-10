/// Mirrors `public.organisation_staff_requests`: a person an organisation's
/// head or admin asked UbuntuID to give an account. An UbuntuID
/// administrator approves (creating `firstname@<domain>`) or declines it.
class StaffRequestItem {
  const StaffRequestItem({
    required this.requestId,
    required this.organisationId,
    required this.organisationName,
    required this.firstName,
    required this.lastName,
    required this.idNumber,
    required this.status,
    required this.createdAt,
    this.declineReason,
    this.createdEmail,
    this.organisationDomain,
  });

  final String requestId;
  final String organisationId;
  final String organisationName;
  final String firstName;
  final String lastName;
  final String idNumber;

  /// 'pending' | 'approved' | 'declined'.
  final String status;
  final DateTime createdAt;
  final String? declineReason;

  /// The sign-in email the approved account got.
  final String? createdEmail;

  /// `karoo.co.za` -- the domain the organisation registered with.
  final String? organisationDomain;

  String get fullName => '$firstName $lastName';

  factory StaffRequestItem.fromRow(Map<String, dynamic> row) {
    final org = row['organisations'] as Map<String, dynamic>?;
    final user = row['organisation_users'] as Map<String, dynamic>?;
    final contactEmail = org?['contact_email'] as String? ?? '';
    final at = contactEmail.indexOf('@');
    return StaffRequestItem(
      requestId: row['request_id'] as String,
      organisationId: row['organisation_id'] as String,
      organisationName: org?['legal_name'] as String? ?? '',
      firstName: row['first_name'] as String? ?? '',
      lastName: row['last_name'] as String? ?? '',
      idNumber: row['id_number'] as String? ?? '',
      status: row['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      declineReason: row['decline_reason'] as String?,
      createdEmail: user?['email'] as String?,
      organisationDomain: at >= 0 ? contactEmail.substring(at + 1) : null,
    );
  }

  static const selectColumns = 'request_id, organisation_id, first_name, last_name, id_number, status, created_at, '
      'decline_reason, organisations(legal_name, contact_email), '
      'organisation_users!organisation_staff_requests_organisation_user_id_fkey(email)';
}
