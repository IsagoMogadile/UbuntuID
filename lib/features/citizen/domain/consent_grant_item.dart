/// Mirrors `consent_grants` -- which organisations currently hold consent
/// to verify which of this citizen's credential types.
class ConsentGrantItem {
  const ConsentGrantItem({
    required this.consentId,
    required this.organisationName,
    required this.credentialTypeNames,
    required this.grantedAt,
    this.expiresAt,
    this.revokedAt,
  });

  final String consentId;
  final String organisationName;
  final List<String> credentialTypeNames;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;

  bool get isActive =>
      revokedAt == null && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
}
