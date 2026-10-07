/// The `credentials.status` column isn't kept in sync as time passes --
/// nothing flips it from `active` to `expired` once `expiry_date` is in the
/// past (there's no scheduled job for it). Recompute it for display so an
/// expired credential is never shown or counted as active, regardless of
/// how stale the stored column is. Shared by every screen and report that
/// reads `credentials`.
String effectiveCredentialStatus(String? status, DateTime? expiryDate) {
  final raw = status ?? 'pending';
  if (raw == 'active' && expiryDate != null && expiryDate.isBefore(DateTime.now())) {
    return 'expired';
  }
  return raw;
}
