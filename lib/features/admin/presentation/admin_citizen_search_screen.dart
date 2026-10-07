import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/presentation/citizen_lookup_screen.dart';
import '../data/admin_repository.dart';

/// Generic citizen search for platform-wide administrator oversight,
/// reached from the admin header's search field. [initialIdNumber] is the
/// ID typed there (`?id=`), searched immediately.
class AdminCitizenSearchScreen extends ConsumerWidget {
  const AdminCitizenSearchScreen({super.key, this.initialIdNumber});

  final String? initialIdNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(adminRepositoryProvider);
    return CitizenLookupScreen(onSearch: repo.searchCitizens, initialIdNumber: initialIdNumber);
  }
}
