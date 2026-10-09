import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/admin_repository.dart';
import '../domain/department_list_item.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';

class DepartmentDetailScreen extends ConsumerStatefulWidget {
  const DepartmentDetailScreen({super.key, required this.departmentId});

  final String departmentId;

  @override
  ConsumerState<DepartmentDetailScreen> createState() => _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends ConsumerState<DepartmentDetailScreen> {
  bool _isSubmitting = false;

  Future<void> _toggleActive(DepartmentListItem department) async {
    if (department.active &&
        !await confirmAction(
          context,
          title: 'Deactivate ${department.departmentName}?',
          message: 'Its officials will lose access until the department is reactivated. Its records are kept.',
          confirmLabel: 'Deactivate department',
          destructive: true,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(adminRepositoryProvider).setDepartmentActive(department.departmentId, !department.active);
      ref.invalidate(adminDepartmentsProvider);
      if (mounted) {
        AppToast.success(context, department.active ? 'Department deactivated.' : 'Department reactivated.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not update this department.', error: e);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departmentsAsync = ref.watch(adminDepartmentsProvider);
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Department')),
      body: departmentsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(message: 'Could not load this department.', onRetry: () => ref.invalidate(adminDepartmentsProvider)),
        data: (departments) {
          final matches = departments.where((d) => d.departmentId == widget.departmentId);
          final department = matches.isEmpty ? null : matches.first;
          if (department == null) {
            return const EmptyState(icon: Icons.search_off_outlined, title: 'Department not found', message: 'It may have been removed, or the link is out of date. Go back and try again.');
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(department.departmentName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    StatusBadge.fromStatus(department.active ? 'active' : 'inactive'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow(label: 'Category', value: department.category),
                    DetailRow(label: 'Contact', value: department.contactEmail),
                    DetailRow(label: 'Officials', value: '${department.officialsCount}'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: department.active ? 'Deactivate department' : 'Reactivate department',
                icon: department.active ? Icons.block_outlined : Icons.check_circle_outline,
                variant: department.active ? AppButtonVariant.secondary : AppButtonVariant.primary,
                expand: true,
                loading: _isSubmitting,
                onPressed: _isSubmitting ? null : () => _toggleActive(department),
              ),
              const SizedBox(height: 8),
              const Text(
                'Deactivating only pauses this department. Nothing is deleted, and you can reactivate it at any time.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Department officials'),
              usersAsync.when(
                loading: () => const LoadingIndicator(),
                error: (error, _) => ErrorView(message: 'Could not load officials.', onRetry: () => ref.invalidate(adminUsersProvider)),
                data: (users) {
                  final officials = users
                      .where((u) => u.roleLabel == 'Department Official' && u.departmentId == widget.departmentId)
                      .toList();
                  if (officials.isEmpty) {
                    return const EmptyState(icon: Icons.badge_outlined, title: 'No officials listed', message: 'Officials assigned to this department will appear here.');
                  }
                  return AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < officials.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            title: Text(officials[i].displayName),
                            subtitle: Text(officials[i].email),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
