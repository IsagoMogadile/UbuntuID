/// Mirrors `public.verification_requests` (+ a display-only citizen label,
/// since resolving `citizen_id` to a name requires a join UbuntuID has not
/// wired up yet). See docs/SCREEN_DATABASE_MAP.md.
class VerificationRequestSummary {
  const VerificationRequestSummary({
    required this.requestId,
    required this.citizenDisplayName,
    required this.organisationName,
    required this.overallStatus,
    required this.requestedAt,
    this.organisationId,
    this.citizenId,
    this.respondedAt,
    this.processingStartedAt,
    this.orgViewedAt,
  });

  final String requestId;
  final String? organisationId;
  final String? citizenId;
  final String citizenDisplayName;
  final String organisationName;

  /// 'pending' | 'processing' | 'completed' | 'partially_verified' |
  /// 'failed' | 'rejected' | 'cancelled'.
  final String overallStatus;
  final DateTime requestedAt;
  final DateTime? respondedAt;

  /// Set when the organisation starts the automated check
  /// (`start_verification`), cleared for nothing -- stays set even after
  /// completion, as a record of when review began.
  final DateTime? processingStartedAt;

  /// Set once the requesting organisation has acknowledged a completed
  /// result (`acknowledge_verification_result`) -- once non-null, the
  /// organisation's own detail view stops showing the per-credential
  /// claimed/verified comparison, only the final status.
  final DateTime? orgViewedAt;
}

/// Mirrors `public.verification_results` for a single request.
class VerificationResultLine {
  const VerificationResultLine({
    required this.credentialTypeName,
    required this.claimedValue,
    required this.verifiedValue,
    required this.matchStatus,
  });

  final String credentialTypeName;
  final String claimedValue;
  final String verifiedValue;
  final String matchStatus;
}
