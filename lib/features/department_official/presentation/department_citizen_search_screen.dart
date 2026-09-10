import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/presentation/citizen_lookup_screen.dart';
import '../data/department_repository.dart';

/// Generic citizen search, reachable from every department official's
/// dashboard regardless of department category.
class DepartmentCitizenSearchScreen extends ConsumerWidget {
  const DepartmentCitizenSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(departmentRepositoryProvider);
    return CitizenLookupScreen(onSearch: repo.searchCitizens);
  }
}
