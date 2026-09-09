/// Mirrors `organisation_users` -- a fellow user in the signed-in user's
/// own organisation.
class OrganisationColleagueItem {
  const OrganisationColleagueItem({
    required this.organisationUserId,
    required this.fullName,
    required this.userRole,
    required this.active,
  });

  final String organisationUserId;
  final String fullName;

  /// 'manager' (Head) | 'administrator' (Admin) | 'member' (Staff).
  final String userRole;
  final bool active;

  String get roleLabel => switch (userRole) {
        'manager' => 'Organisational Head',
        'administrator' => 'Organisational Admin',
        _ => 'Staff',
      };
}
