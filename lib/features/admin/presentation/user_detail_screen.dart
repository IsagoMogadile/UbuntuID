import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/admin_repository.dart';
import '../domain/user_list_item.dart';
import 'digital_profile_view.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';

class UserDetailScreen extends ConsumerStatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  bool _isSubmitting = false;

  Future<void> _toggleActive(UserListItem user) async {
    if (user.active &&
        !await confirmAction(
          context,
          title: 'Suspend ${user.displayName}?',
          message: 'They will not be able to sign in until you reactivate the account. Nothing is deleted.',
          confirmLabel: 'Suspend account',
          destructive: true,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(adminRepositoryProvider).setUserActive(
            role: user.role,
            userId: user.userId,
            active: !user.active,
          );
      ref.invalidate(adminUsersProvider);
      if (mounted) {
        AppToast.success(context, user.active ? 'Account suspended.' : 'Account reactivated.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not update this account.', error: e);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete(UserListItem user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Delete ${user.displayName}?'),
        content: Text('This permanently removes ${user.displayName} and their account. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete official')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(adminRepositoryProvider).deleteDepartmentOfficial(user.userId);
      ref.invalidate(adminUsersProvider);
      if (mounted) {
        AppToast.success(context, 'Official deleted.');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not delete this official.', error: e);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('User')),
      body: usersAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(message: 'Could not load this user.', onRetry: () => ref.invalidate(adminUsersProvider)),
        data: (users) {
          final matches = users.where((u) => u.userId == widget.userId);
          final user = matches.isEmpty ? null : matches.first;
          if (user == null) {
            return const EmptyState(icon: Icons.search_off_outlined, title: 'User not found', message: 'It may have been removed, or the link is out of date. Go back and try again.');
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(user.email),
                        ],
                      ),
                    ),
                    StatusBadge.fromStatus(user.active ? 'active' : 'inactive'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow(label: 'Role', value: user.roleLabel),
                    DetailRow(label: 'Created', value: AppFormatters.date(user.createdAt)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Digital profile', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              switch (ref.watch(adminUserIdNumberProvider((role: user.role, userId: user.userId)))) {
                AsyncData(value: final idNumber?) when idNumber.isNotEmpty => DigitalProfileView(idNumber: idNumber),
                AsyncData() => const AppCard(child: Text('No ID number on this account, so there is no digital profile to show.')),
                AsyncError() => const AppCard(child: Text("Could not load this person's ID number.")),
                _ => const LoadingIndicator(),
              },
              const SizedBox(height: 20),
              if (user.role == AdminUserRole.departmentOfficial) ...[
                AppButton(
                  label: 'Edit official',
                  icon: Icons.edit_outlined,
                  expand: true,
                  onPressed: () => context.push('${AppRoutes.adminOfficialEdit}/${user.userId}/edit'),
                ),
                const SizedBox(height: 10),
              ],
              AppButton(
                label: user.active ? 'Suspend account' : 'Reactivate account',
                icon: user.active ? Icons.block_outlined : Icons.check_circle_outline,
                variant: user.active ? AppButtonVariant.secondary : AppButtonVariant.primary,
                expand: true,
                loading: _isSubmitting,
                onPressed: _isSubmitting ? null : () => _toggleActive(user),
              ),
              const SizedBox(height: 8),
              const Text(
                'Suspending only blocks sign-in. Nothing is deleted, and you can reactivate the account at any time.',
                style: TextStyle(fontSize: 12),
              ),
              if (user.role == AdminUserRole.departmentOfficial) ...[
                const SizedBox(height: 16),
                AppButton(
                  label: 'Delete official',
                  icon: Icons.delete_outline,
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  loading: _isSubmitting,
                  onPressed: _isSubmitting ? null : () => _delete(user),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Permanently removes this official\'s profile and account.',
                  style: TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
