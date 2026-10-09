import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/accessibility_link.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../services/service_providers.dart';
import '../data/department_repository.dart';

class DepartmentProfileScreen extends ConsumerWidget {
  const DepartmentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authServiceProvider).currentUser?.email ?? 'Unknown';
    final profileAsync = ref.watch(departmentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load your profile.',
          onRetry: () => ref.invalidate(departmentProfileProvider),
        ),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'Official information'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DetailRow(label: 'Name', value: profile.fullName),
                  DetailRow(label: 'Email', value: email),
                  DetailRow(label: 'Role', value: profile.officialRole),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Department'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DetailRow(label: 'Department', value: profile.departmentName),
                  if (profile.departmentCategory != null)
                    DetailRow(label: 'Category', value: profile.departmentCategory!),
                  DetailRow(label: 'Status', value: profile.active ? 'Active' : 'Inactive'),
                ],
              ),
            ),
            const AccessibilityProfileLink(),
          ],
        ),
      ),
    );
  }
}
