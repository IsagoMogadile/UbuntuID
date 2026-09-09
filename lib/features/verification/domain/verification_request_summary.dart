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
    this.respondedAt,
  });

  final String requestId;
  final String citizenDisplayName;
  final String organisationName;
  final String overallStatus;
  final DateTime requestedAt;
  final DateTime? respondedAt;
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
