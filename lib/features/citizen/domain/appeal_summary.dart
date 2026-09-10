/// This citizen's own view of one of their `public.appeals` rows --
/// lighter than the admin-facing `AppealItem` (no lodging-official name,
/// since that's not the citizen's business).
class AppealSummary {
  const AppealSummary({
    required this.appealId,
    required this.departmentName,
    required this.appealReason,
    required this.status,
    required this.submittedAt,
    this.decision,
    this.decisionNotes,
  });

  final String appealId;
  final String departmentName;
  final String appealReason;

  /// 'submitted' | 'under_review' | 'upheld' | 'rejected' | 'withdrawn'.
  final String status;
  final DateTime submittedAt;
  final String? decision;
  final String? decisionNotes;
}
