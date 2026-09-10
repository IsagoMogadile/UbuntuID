/// Mirrors one of the citizen's own `public.organisation_employees` rows --
/// the organisation's own HR record of employing this citizen (separate
/// from the government's `labour_employment_records`, which the
/// Employment & Labour department manages and which this citizen sees via
/// the "Employment & UIF" credential instead).
class EmploymentItem {
  const EmploymentItem({
    required this.employeeId,
    required this.organisationName,
    required this.jobTitle,
    this.departmentOrPosition,
    this.salary,
    required this.salaryFrequency,
    required this.employmentStatus,
    required this.startDate,
  });

  final String employeeId;
  final String organisationName;
  final String jobTitle;
  final String? departmentOrPosition;
  final num? salary;
  final String salaryFrequency;
  final String employmentStatus;
  final DateTime startDate;
}
