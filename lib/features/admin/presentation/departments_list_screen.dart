import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/admin_repository.dart';

class DepartmentsListScreen extends ConsumerWidget {
  const DepartmentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentsAsync = ref.watch(adminDepartmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_outlined),
            tooltip: 'Add department',
            onPressed: () => context.push(AppRoutes.adminDepartmentNew),
          ),
        ],
      ),
      body: departmentsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load departments.',
          onRetry: () => ref.invalidate(adminDepartmentsProvider),
        ),
        data: (departments) {
          if (departments.isEmpty) {
            return const EmptyState(icon: Icons.account_balance_outlined, title: 'No departments found', message: 'Try a different search, or add a department.');
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: departments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final department = departments[index];
              return ListItemCard(
                title: department.departmentName,
                subtitle: '${department.category} • ${department.officialsCount} officials',
                leadingIcon: Icons.account_balance_outlined,
                trailing: StatusBadge.fromStatus(department.active ? 'active' : 'inactive'),
                onTap: () => context.push('${AppRoutes.adminDepartments}/${department.departmentId}'),
              );
            },
          );
        },
      ),
    );
  }
}
