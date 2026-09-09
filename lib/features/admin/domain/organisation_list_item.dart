/// Mirrors `public.organisations`.
class OrganisationListItem {
  const OrganisationListItem({
    required this.organisationId,
    required this.legalName,
    required this.organisationType,
    required this.accessTier,
    required this.verified,
    required this.contactEmail,
    required this.registeredAt,
    required this.registrationStatus,
    this.declineReason,
  });

  final String organisationId;
  final String legalName;
  final String organisationType;
  final String accessTier;
  final bool verified;
  final String contactEmail;
  final DateTime registeredAt;

  /// 'pending' | 'approved' | 'declined'.
  final String registrationStatus;
  final String? declineReason;
}
