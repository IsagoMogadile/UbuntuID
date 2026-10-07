import 'package:flutter/material.dart';

class DepartmentDashboardStats {
  const DepartmentDashboardStats({
    required this.departmentName,
    required this.activeOfficials,
    this.categoryStats = const [],
    this.recordsByService = const [],
  });

  final String departmentName;
  final int activeOfficials;

  /// Extra stat cards specific to this department's category (Home
  /// Affairs/SASSA/Basic Education/Higher Education/SAPS) -- built by
  /// `DepartmentRepository.getDashboardStats`. Empty for a department not
  /// explicitly modelled, so every department still gets the 3 generic
  /// stats above with no regression.
  final List<DepartmentStatItem> categoryStats;

  /// Live row count per record type this department manages (label from
  /// `recordTypesForDepartment`), e.g. ('Passport', 42). A record type whose
  /// table this official can't read is left out rather than shown as 0.
  final List<(String, int)> recordsByService;

  int get totalRecords => recordsByService.fold(0, (sum, e) => sum + e.$2);
}

class DepartmentStatItem {
  const DepartmentStatItem({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;
}
