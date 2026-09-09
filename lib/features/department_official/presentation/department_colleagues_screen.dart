import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/staggered_fade_in.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/department_repository.dart';

const _adminTiers = {'Departmental Head', 'Departmental Admin'};

/// Fellow officials in the signed-in official's own department -- reached
/// by tapping the "Officials" stat on the department dashboard. A
/// Departmental Head or Admin additionally gets an "Add staff" action and
/// can toggle a colleague's active status, via the `dept_admin_*` RPCs --
/// self-service that previously only a System Administrator could do.
class DepartmentColleaguesScreen extends ConsumerStatefulWidget {
  const DepartmentColleaguesScreen({super.key});

  @override
  ConsumerState<DepartmentColleaguesScreen> createState() => _DepartmentColleaguesScreenState();
}

class _DepartmentColleaguesScreenState extends ConsumerState<DepartmentColleaguesScreen> {
  String? _togglingId;

  Future<void> _addStaff(bool isAdminTier) async {
    if (!isAdminTier) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const _AddStaffDialog(),
    );
    if (created == true) {
      ref.invalidate(departmentColleaguesProvider);
    }
  }

  Future<void> _toggleActive(String officialId, bool currentlyActive) async {
    setState(() => _togglingId = officialId);
    try {
      await ref.read(departmentRepositoryProvider).setOfficialActive(officialId, !currentlyActive);
      ref.invalidate(departmentColleaguesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update this official: $e')));
      }
    } finally {
      if (mounted) setState(() => _togglingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colleaguesAsync = ref.watch(departmentColleaguesProvider);
    final profileAsync = ref.watch(departmentProfileProvider);
    final isAdminTier = _adminTiers.contains(profileAsync.value?.officialRole);

    return Scaffold(
      appBar: AppBar(title: const Text('Officials')),
      floatingActionButton: isAdminTier
          ? FloatingActionButton.extended(
              onPressed: () => _addStaff(true),
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Add staff'),
            )
          : null,
      body: colleaguesAsync.when(
        loading: () => const ShimmerListPlaceholder(itemCount: 4),
        error: (error, _) => ErrorView(
          message: 'Could not load officials.',
          onRetry: () => ref.invalidate(departmentColleaguesProvider),
        ),
        data: (colleagues) {
          if (colleagues.isEmpty) {
            return const EmptyState(icon: Icons.badge_outlined, title: 'No officials found');
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: colleagues.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final colleague = colleagues[index];
              final canToggle = isAdminTier && colleague.officialRole != 'Departmental Head';
              return StaggeredFadeIn(
                index: index,
                child: ListItemCard(
                  title: colleague.fullName,
                  subtitle: colleague.officialRole,
                  leadingIcon: Icons.person_outline,
                  trailing: canToggle
                      ? _togglingId == colleague.officialId
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Switch(
                              value: colleague.active,
                              onChanged: (_) => _toggleActive(colleague.officialId, colleague.active),
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

class _AddStaffDialog extends ConsumerStatefulWidget {
  const _AddStaffDialog();

  @override
  ConsumerState<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends ConsumerState<_AddStaffDialog> {
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
      final result = await ref.read(departmentRepositoryProvider).createStaffMember(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Staff account created: ${result['email']}')),
        );
      }
    } catch (e) {
      setState(() => _error = 'Could not create this account: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add staff member'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'First name',
                controller: _firstNameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Last name',
                controller: _lastNameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Password',
                controller: _passwordController,
                obscureText: true,
                validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
              ),
              const SizedBox(height: 4),
              const Text(
                'Login email is auto-generated from their name and your department\'s domain.',
                style: TextStyle(fontSize: 12, color: AppColors.charcoalMuted),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        AppButton(label: 'Create', loading: _submitting, onPressed: _submitting ? null : _submit),
      ],
    );
  }
}
