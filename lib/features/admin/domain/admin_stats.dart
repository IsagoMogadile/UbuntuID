class AdminStats {
  const AdminStats({
    required this.totalCitizens,
    required this.departmentOfficials,
    required this.organisations,
    required this.pendingVerifications,
    required this.flaggedRecords,
    required this.recentAuditEvents,
  });

  final int totalCitizens;
  final int departmentOfficials;
  final int organisations;
  final int pendingVerifications;
  final int flaggedRecords;
  final int recentAuditEvents;
}
