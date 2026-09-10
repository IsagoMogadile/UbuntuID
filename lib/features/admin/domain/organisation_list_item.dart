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
    this.revokedAt,
    this.revokeReason,
    this.reinstatedAt,
    this.reinstateReason,
  });

  final String organisationId;
  final String legalName;
  final String organisationType;
  final String accessTier;
  final bool verified;
  final String contactEmail;
  final DateTime registeredAt;

  /// 'pending' | 'approved' | 'declined' | 'revoked'.
  final String registrationStatus;
  final String? declineReason;

  /// Set together when an admin revokes this organisation
  /// (`admin_revoke_organisation` RPC) -- a reason is always required.
  final DateTime? revokedAt;
  final String? revokeReason;

  /// Set together when an admin reinstates a revoked organisation
  /// (`admin_reinstate_organisation` RPC) -- a reason is always required.
  /// Both this and [revokedAt]/[revokeReason] are kept (not cleared) after
  /// a reinstate, so the history stays visible.
  final DateTime? reinstatedAt;
  final String? reinstateReason;
}
