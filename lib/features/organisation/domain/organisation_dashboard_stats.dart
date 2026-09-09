class OrganisationDashboardStats {
  const OrganisationDashboardStats({
    required this.organisationName,
    required this.accessTier,
    required this.verified,
    required this.pendingVerifications,
    required this.completedThisMonth,
  });

  final String organisationName;
  final String accessTier;
  final bool verified;
  final int pendingVerifications;
  final int completedThisMonth;
}
