/// Every kind of actor the administrator's universal header search covers --
/// the four role tables plus the organisations and departments themselves.
enum AdminSearchKind {
  citizen('Citizens'),
  departmentOfficial('Department officials'),
  organisationUser('Organisation users'),
  administrator('Administrators'),
  organisation('Organisations'),
  department('Departments');

  const AdminSearchKind(this.label);

  final String label;
}

/// One row in the administrator's universal search results. [id] is the
/// row's own primary key, so it routes straight to the matching admin detail
/// screen (users, organisations or departments).
class AdminSearchHit {
  const AdminSearchHit({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final AdminSearchKind kind;
  final String id;
  final String title;
  final String subtitle;
  final String status;
}
