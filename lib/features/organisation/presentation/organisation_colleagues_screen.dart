import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/staggered_fade_in.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/organisation_repository.dart';
import '../domain/staff_request_item.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/widgets/app_form_dialog.dart';

const _orgAdminTiers = {'manager', 'administrator'};

/// Fellow users in the signed-in user's own organisation. An
/// Organisational Head or Admin can toggle a colleague's active status and
/// request new staff -- an UbuntuID administrator then creates the account
/// (organisations no longer create accounts themselves).
class OrganisationColleaguesScreen extends ConsumerStatefulWidget {
  const OrganisationColleaguesScreen({super.key});

  @override
  ConsumerState<OrganisationColleaguesScreen> createState() => _OrganisationColleaguesScreenState();
}

class _OrganisationColleaguesScreenState extends ConsumerState<OrganisationColleaguesScreen> {
  String? _togglingId;

  Future<void> _requestStaff() async {
    final sent = await showDialog<int>(
      context: context,
      builder: (context) => const _RequestStaffDialog(),
    );
    if (sent != null && sent > 0) {
      ref.invalidate(organisationStaffRequestsProvider);
      if (mounted) {
        AppToast.success(
          context,
          sent == 1 ? 'Request sent. UbuntuID will add them shortly.' : '$sent requests sent. UbuntuID will add them shortly.',
        );
      }
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
    final requests = isAdminTier ? ref.watch(organisationStaffRequestsProvider).value ?? const <StaffRequestItem>[] : const <StaffRequestItem>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Colleagues')),
      floatingActionButton: isAdminTier
          ? FloatingActionButton.extended(
              onPressed: _requestStaff,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Request staff'),
            )
          : null,
      body: colleaguesAsync.when(
        loading: () => const ShimmerListPlaceholder(itemCount: 3),
        error: (error, _) => ErrorView(
          message: 'Could not load colleagues.',
          onRetry: () => ref.invalidate(organisationColleaguesProvider),
        ),
        data: (colleagues) {
          if (colleagues.isEmpty && requests.isEmpty) {
            return const EmptyState(icon: Icons.group_outlined, title: 'No colleagues found', message: 'Request staff to add colleagues.');
          }
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              for (final (index, colleague) in colleagues.indexed) ...[
                StaggeredFadeIn(
                  index: index,
                  child: ListItemCard(
                    title: colleague.fullName,
                    subtitle: colleague.roleLabel,
                    leadingIcon: Icons.person_outline,
                    trailing: isAdminTier && colleague.userRole != 'manager'
                        ? _togglingId == colleague.organisationUserId
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Switch(
                                value: colleague.active,
                                onChanged: (_) => _toggleActive(colleague.organisationUserId, colleague.active),
                              )
                        : StatusBadge.fromStatus(colleague.active ? 'active' : 'inactive'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (requests.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Staff requests', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'UbuntuID adds each person after checking they are a registered citizen.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.charcoalMuted),
                ),
                const SizedBox(height: 10),
                for (final r in requests) ...[
                  ListItemCard(
                    title: r.fullName,
                    subtitle: switch (r.status) {
                      'approved' => 'Added · signs in as ${r.createdEmail ?? 'their new email'}',
                      'declined' => 'Declined · ${r.declineReason ?? ''}',
                      _ => 'Requested ${AppFormatters.date(r.createdAt)} · waiting for UbuntuID',
                    },
                    leadingIcon: Icons.how_to_reg_outlined,
                    trailing: StatusBadge.fromStatus(r.status),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PersonFields {
  final first = TextEditingController();
  final last = TextEditingController();
  final id = TextEditingController();

  void dispose() {
    first.dispose();
    last.dispose();
    id.dispose();
  }
}

class _RequestStaffDialog extends ConsumerStatefulWidget {
  const _RequestStaffDialog();

  @override
  ConsumerState<_RequestStaffDialog> createState() => _RequestStaffDialogState();
}

class _RequestStaffDialogState extends ConsumerState<_RequestStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<_PersonFields> _people = [_PersonFields()];
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final p in _people) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final sent = await ref.read(organisationRepositoryProvider).requestStaff([
        for (final p in _people)
          (
            firstName: p.first.text.trim(),
            lastName: p.last.text.trim(),
            idNumber: AppFormatters.compactIdNumber(p.id.text),
          ),
      ]);
      if (mounted) Navigator.pop(context, sent);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppFormDialog(
      title: 'Request staff',
      subtitle: 'Each person must be an UbuntuID citizen. UbuntuID creates their account as firstname@your domain.',
      submitLabel: _people.length == 1 ? 'Send request' : 'Send ${_people.length} requests',
      submitting: _submitting,
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, p) in _people.indexed) ...[
              Row(
                children: [
                  Expanded(child: Text('Person ${i + 1}', style: theme.textTheme.titleSmall)),
                  if (_people.length > 1)
                    IconButton(
                      tooltip: 'Remove person ${i + 1}',
                      icon: const Icon(Icons.close),
                      onPressed: _submitting
                          ? null
                          : () => setState(() {
                                _people.removeAt(i).dispose();
                              }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'First name',
                      controller: p.first,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      label: 'Last name',
                      controller: p.last,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppTextField(
                label: 'SA ID number',
                controller: p.id,
                keyboardType: TextInputType.number,
                validator: (v) => AppFormatters.compactIdNumber(v ?? '').length != 13 ? 'Enter a 13-digit ID number' : null,
              ),
              const SizedBox(height: 16),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _submitting ? null : () => setState(() => _people.add(_PersonFields())),
                icon: const Icon(Icons.add),
                label: const Text('Add another person'),
              ),
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
