/// Mirrors `human_settlements_records` (joined with `citizens` and
/// `properties` for display) -- generic household/occupancy data with no
/// dedicated department, so it's an administrator-oversight screen rather
/// than a department-official one.
class HouseholdRecordItem {
  const HouseholdRecordItem({
    required this.recordId,
    required this.recordType,
    required this.recordedAt,
    required this.citizenName,
    required this.propertyReference,
    required this.recordData,
  });

  final String recordId;
  final String recordType;
  final DateTime recordedAt;
  final String citizenName;
  final String propertyReference;
  final Map<String, dynamic> recordData;
}
