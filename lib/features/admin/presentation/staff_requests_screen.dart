import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_destructive_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../../organisation/domain/staff_request_item.dart';
import '../data/admin_repository.dart';

/// People organisations have asked UbuntuID to give staff accounts.
/// Organisations can no longer create accounts themselves: the
/// administrator checks the person (their digital profile is one tap away)
/// and approves -- creating `firstname@<domain>` -- or declines.
class StaffRequestsScreen extends ConsumerStatefulWidget {
  const StaffRequestsScreen({super.key});

  @override
  ConsumerState<StaffRequestsScreen> createState() => _StaffRequestsScreenState();
}

class _StaffRequestsScreenState extends ConsumerState<StaffRequestsScreen> {
  String? _busyId;

  Future<void> _approve(StaffRequestItem r) async {
    final email = await showDialog<String>(context: context, builder: (_) => _ApproveDialog(request: r));
    if (email == null || !mounted) return;
    ref.invalidate(adminStaffRequestsProvider);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: const Icon(Icons.check_circle_outline, color: AppColors.green),
        title: Text('${r.fullName} added'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.organisationName} has been notified. ${r.firstName} signs in with:'),
            const SizedBox(height: 12),
            SelectableText(email, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy email'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: email));
              AppToast.success(context, 'Email copied.');
            },
          ),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _decline(StaffRequestItem r) async {
    final reason = await confirmDestructive(
      context,
      title: 'Decline ${r.fullName}?',
      consequence: "${r.organisationName}'s request will be declined and its head told your reason. No account is created.",
      confirmText: r.fullName,
      confirmLabel: 'Decline request',
      reasonLabel: 'Reason (shown to the organisation)',
    );
    if (reason == null || !mounted) return;
    setState(() => _busyId = r.requestId);
    try {
      await ref.read(adminRepositoryProvider).decideStaffRequest(requestId: r.requestId, approve: false, reason: reason);
      ref.invalidate(adminStaffRequestsProvider);
      if (mounted) AppToast.success(context, 'Request declined.');
    } catch (e) {
      if (mounted) AppToast.error(context, 'Could not decline this request.', error: e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(adminStaffRequestsProvider);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: AppColors.charcoalMuted);

    return Scaffold(
      appBar: AppBar(title: const Text('Staff requests')),
      body: requestsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(message: 'Could not load staff requests.', onRetry: () => ref.invalidate(adminStaffRequestsProvider)),
        data: (requests) {
          if (requests.isEmpty) {
            return const EmptyState(
              icon: Icons.how_to_reg_outlined,
              title: 'No staff requests',
              message: 'When an organisation asks for a staff account, it appears here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(adminStaffRequestsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final r = requests[index];
                final pending = r.status == 'pending';
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(r.fullName, style: theme.textTheme.titleMedium)),
                          StatusBadge.fromStatus(r.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${r.organisationName} · ID ${r.idNumber} · requested ${AppFormatters.date(r.createdAt)}', style: muted),
                      if (r.status == 'approved' && r.createdEmail != null)
                        Padding(padding: const EdgeInsets.only(top: 4), child: Text('Signs in as ${r.createdEmail}', style: muted)),
                      if (r.status == 'declined' && r.declineReason != null)
                        Padding(padding: const EdgeInsets.only(top: 4), child: Text('Declined: ${r.declineReason}', style: muted)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.badge_outlined, size: 18),
                            label: const Text('Digital profile'),
                            onPressed: () => context.push('${AppRoutes.adminPersonProfile}/${r.idNumber}'),
                          ),
                          if (pending) ...[
                            FilledButton.icon(
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Approve'),
                              onPressed: _busyId == null ? () => _approve(r) : null,
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Decline'),
                              onPressed: _busyId == null ? () => _decline(r) : null,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ApproveDialog extends ConsumerStatefulWidget {
  const _ApproveDialog({required this.request});

  final StaffRequestItem request;

  @override
  ConsumerState<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends ConsumerState<_ApproveDialog> {
  late final _password = TextEditingController(
    text: '${widget.request.firstName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}@123',
  );
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final email = await ref.read(adminRepositoryProvider).decideStaffRequest(
            requestId: widget.request.requestId,
            approve: true,
            password: _password.text,
          );
      if (mounted) Navigator.pop(context, email);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final slug = r.firstName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return AppFormDialog(
      title: 'Approve ${r.fullName}',
      subtitle: 'Creates a staff account at ${r.organisationName}.',
      submitLabel: 'Create account',
      submitting: _submitting,
      onSubmit: _submit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign-in email: $slug@${r.organisationDomain ?? 'their domain'} '
            '(a number is added if that name is already taken).',
          ),
          const SizedBox(height: 14),
          AppTextField(label: 'Starting password', helperText: 'At least 8 characters. Share it with the organisation.', controller: _password),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
