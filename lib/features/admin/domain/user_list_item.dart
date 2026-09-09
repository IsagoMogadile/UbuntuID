/// A unified display row across citizens / department_officials /
/// organisation_users / ubuntuid_administrators. UbuntuID does not merge
/// these into a single real database table.
enum AdminUserRole { citizen, departmentOfficial, organisationUser, administrator }

class UserListItem {
  const UserListItem({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.active,
    required this.createdAt,
  });

  final String userId;
  final String displayName;
  final String email;
  final AdminUserRole role;
  final bool active;
  final DateTime createdAt;

  String get roleLabel => switch (role) {
        AdminUserRole.citizen => 'Citizen',
        AdminUserRole.departmentOfficial => 'Department Official',
        AdminUserRole.organisationUser => 'Organisation User',
        AdminUserRole.administrator => 'Administrator',
      };
}
