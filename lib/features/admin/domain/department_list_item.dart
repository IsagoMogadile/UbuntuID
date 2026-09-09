/// Mirrors `public.departments`.
class DepartmentListItem {
  const DepartmentListItem({
    required this.departmentId,
    required this.departmentName,
    required this.category,
    required this.active,
    required this.officialsCount,
    required this.contactEmail,
  });

  final String departmentId;
  final String departmentName;
  final String category;
  final bool active;
  final int officialsCount;
  final String contactEmail;
}
