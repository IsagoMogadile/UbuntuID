import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/staggered_fade_in.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/organisation_repository.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/widgets/app_form_dialog.dart';

const _orgAdminTiers = {'manager', 'administrator'};

/// Fellow users in the signed-in user's own organisation. An
/// Organisational Head or Admin additionally gets an "Add staff" action
/// and can toggle a colleague's active status.
class OrganisationColleaguesScreen extends ConsumerStatefulWidget {
  const OrganisationColleaguesScreen({super.key});

  @override
  ConsumerState<OrganisationColleaguesScreen> createState() => _OrganisationColleaguesScreenState();
}

class _OrganisationColleaguesScreenState extends ConsumerState<OrganisationColleaguesScreen> {
  String? _togglingId;

  Future<void> _addStaff() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const _AddOrgStaffDialog(),
    );
    if (created == true) {
      ref.invalidate(organisationColleaguesProvider);
    }
  }

  Future<void> _toggleActive(String userId, bool currentlyActive) async {
    setState(() => _togglingId = userId);
    try {
      await ref.read(organisationRepositoryProvider).setUserActive(userId, !currentlyActive);
      ref.invalidate(organisationColleaguesProvider);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not update this user.', error: e);
      }
    } finally {
      if (mounted) setState(() => _togglingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colleaguesAsync = ref.watch(organisationColleaguesProvider);
    final roleAsync = ref.watch(myOrgRoleProvider);
    final isAdminTier = _orgAdminTiers.contains(roleAsync.value);

    return Scaffold(
      appBar: AppBar(title: const Text('Colleagues')),
      floatingActionButton: isAdminTier
          ? FloatingActionButton.extended(
              onPressed: _addStaff,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Add staff'),
            )
          : null,
      body: colleaguesAsync.when(
        loading: () => const ShimmerListPlaceholder(itemCount: 3),
        error: (error, _) => ErrorView(
          message: 'Could not load colleagues.',
          onRetry: () => ref.invalidate(organisationColleaguesProvider),
        ),
        data: (colleagues) {
          if (colleagues.isEmpty) {
            return const EmptyState(icon: Icons.group_outlined, title: 'No colleagues found', message: 'Try a different search, or add a colleague.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: colleagues.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final colleague = colleagues[index];
              final canToggle = isAdminTier && colleague.userRole != 'manager';
              return StaggeredFadeIn(
                index: index,
                child: ListItemCard(
                  title: colleague.fullName,
                  subtitle: colleague.roleLabel,
                  leadingIcon: Icons.person_outline,
                  trailing: canToggle
                      ? _togglingId == colleague.organisationUserId
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Switch(
                              value: colleague.active,
                              onChanged: (_) => _toggleActive(colleague.organisationUserId, colleague.active),
                            )
                      : StatusBadge.fromStatus(colleague.active ? 'active' : 'inactive'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AddOrgStaffDialog extends ConsumerStatefulWidget {
  const _AddOrgStaffDialog();

  @override
  ConsumerState<_AddOrgStaffDialog> createState() => _AddOrgStaffDialogState();
}

class _AddOrgStaffDialogState extends ConsumerState<_AddOrgStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(organisationRepositoryProvider).createStaffMember(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) {
        Navigator.pop(context, true);
        AppToast.success(context, 'Staff account created: ${result['email']}');
      }
    } catch (e) {
      setState(() => _error = 'Could not create this account. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: 'Add staff member',
      subtitle: 'They can sign in straight away with the password you set here.',
      submitLabel: 'Create account',
      submitting: _submitting,
      onSubmit: _submit,
      child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'First name',
                controller: _firstNameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter their first name.' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Last name',
                controller: _lastNameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter their last name.' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Password',
                helperText: 'At least 8 characters.',
                controller: _passwordController,
                obscureText: true,
                validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters.' : null,
              ),
              const SizedBox(height: 4),
              const Text(
                'Sign-in email is created automatically from their name and your organisation\'s domain.',
                style: TextStyle(fontSize: 12, color: AppColors.charcoalMuted),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
            ],
          ),
        ),
    );
  }
}
