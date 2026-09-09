/// Backs `AdminAnalyticsScreen`'s charts -- 4 small aggregate queries
/// bundled together (`AdminRepository.getAnalytics`), not their own table.
class AdminAnalytics {
  const AdminAnalytics({
    required this.registrationsByMonth,
    required this.verificationsByStatus,
    required this.officialsByDepartment,
    required this.propertiesByProvince,
  });

  /// Last 6 months, oldest first -- `(label, count)`.
  final List<(String, int)> registrationsByMonth;

  /// `verification_requests.overall_status` -> count.
  final Map<String, int> verificationsByStatus;

  /// Department name -> active official count.
  final List<(String, int)> officialsByDepartment;

  /// Province -> property count (Human Settlements).
  final List<(String, int)> propertiesByProvince;
}
