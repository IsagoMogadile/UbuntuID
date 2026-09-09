/// Classifies a department by its `department_name` so a single dashboard
/// screen can show category-appropriate stats/actions without a per-
/// department screen variant (see docs/PROJECT_SCOPE.md §"Department
/// official"). Name-based rather than the live `departments.category`
/// column (values confirmed: revenue/law_enforcement/higher_education/
/// basic_education/housing/identity/transport/labour/social_security) --
/// matching on name is still preferred here since it doesn't depend on
/// that column's exact wording staying stable.
enum DepartmentCategory {
  homeAffairs,
  sassa,
  basicEducation,
  higherEducation,
  saps,
  humanSettlements,
  other;

  static DepartmentCategory fromName(String? departmentName) {
    final name = (departmentName ?? '').toLowerCase();
    if (name.contains('home affairs')) return DepartmentCategory.homeAffairs;
    if (name.contains('sassa') || name.contains('social security')) return DepartmentCategory.sassa;
    // Check "higher education" before the more general "education" match
    // below so the two departments never collide.
    if (name.contains('higher education')) return DepartmentCategory.higherEducation;
    if (name.contains('basic education')) return DepartmentCategory.basicEducation;
    if (name.contains('police') || name.contains('saps')) return DepartmentCategory.saps;
    if (name.contains('human settlements')) return DepartmentCategory.humanSettlements;
    return DepartmentCategory.other;
  }
}
