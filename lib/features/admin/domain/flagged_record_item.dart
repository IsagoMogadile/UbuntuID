/// Mirrors `public.flagged_records`.
class FlaggedRecordItem {
  const FlaggedRecordItem({
    required this.flagId,
    required this.citizenDisplayName,
    required this.reason,
    required this.status,
    required this.raisedAt,
    this.citizenId,
    this.resolutionNotes,
  });

  final String flagId;
  final String citizenDisplayName;
  final String reason;
  final String status;
  final DateTime raisedAt;

  /// Null for a flagged record raised against something other than a
  /// citizen row (e.g. a credential/verification-result flag with no
  /// `citizens` join). When present, the admin UI can link straight to
  /// that citizen's User Management record (e.g. to deactivate their
  /// account after a death is declared -- see
  /// docs/database/declare_citizen_deceased.sql).
  final String? citizenId;
  final String? resolutionNotes;
}
