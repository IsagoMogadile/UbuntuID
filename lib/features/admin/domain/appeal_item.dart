/// Mirrors `public.appeals` -- a citizen (in person, at the department)
/// disputes an existing department record; the lodging official records
/// it (`lodge_appeal` RPC), and an administrator reviews/decides it
/// (`admin_start_appeal_review`/`admin_decide_appeal` RPCs). See
/// docs/database/appeals_workflow.sql.
class AppealItem {
  const AppealItem({
    required this.appealId,
    required this.citizenId,
    required this.citizenDisplayName,
    required this.departmentName,
    required this.relatedTable,
    required this.appealReason,
    required this.status,
    required this.submittedAt,
    this.lodgedByName,
    this.decision,
    this.decisionDate,
    this.decisionNotes,
  });

  final String appealId;
  final String citizenId;
  final String citizenDisplayName;
  final String departmentName;

  /// The Postgres table the disputed record lives in (e.g.
  /// `dot_driver_licences`) -- shown as-is, a raw table name, since there's
  /// no display-name mapping for it and an admin reviewing this already
  /// has database context.
  final String relatedTable;
  final String appealReason;

  /// 'submitted' | 'under_review' | 'upheld' | 'rejected' | 'withdrawn'.
  final String status;
  final DateTime submittedAt;
  final String? lodgedByName;
  final String? decision;
  final DateTime? decisionDate;
  final String? decisionNotes;
}
