import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/presentation/citizen_lookup_screen.dart';
import '../data/department_repository.dart';

/// Generic citizen search, reachable from the department header's search
/// field regardless of department category. [initialIdNumber] is the ID
/// typed into that field (`?id=`), searched immediately.
class DepartmentCitizenSearchScreen extends ConsumerWidget {
  const DepartmentCitizenSearchScreen({super.key, this.initialIdNumber});

  final String? initialIdNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(departmentRepositoryProvider);
    return CitizenLookupScreen(onSearch: repo.searchCitizens, initialIdNumber: initialIdNumber);
  }
}
