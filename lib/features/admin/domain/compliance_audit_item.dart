/// Mirrors `compliance_audits` -- a periodic rollup an admin generates,
/// previously seeded but with no screen built against it.
class ComplianceAuditItem {
  const ComplianceAuditItem({
    required this.auditId,
    required this.periodStart,
    required this.periodEnd,
    required this.generatedAt,
    required this.totalVerificationRequests,
    required this.totalFlaggedRecords,
    required this.totalResolvedRecords,
    this.summary,
    this.generatedByName,
  });

  final String auditId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime generatedAt;
  final int totalVerificationRequests;
  final int totalFlaggedRecords;
  final int totalResolvedRecords;
  final String? summary;
  final String? generatedByName;
}
