/// Full `department_officials` row, used by the admin create/edit form --
/// richer than [UserListItem], which only carries the fields the generic
/// cross-role Users list needs.
class DepartmentOfficialDetail {
  const DepartmentOfficialDetail({
    required this.officialId,
    required this.firstName,
    required this.lastName,
    required this.officialRole,
    required this.departmentId,
    required this.active,
    this.employeeReference,
    this.email,
  });

  final String officialId;
  final String firstName;
  final String lastName;
  final String officialRole;
  final String departmentId;
  final bool active;
  final String? employeeReference;
  final String? email;

  String get fullName => '$firstName $lastName'.trim();
}
