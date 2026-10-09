import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_form_dialog.dart';

class FlaggedRecordDetailScreen extends ConsumerStatefulWidget {
  const FlaggedRecordDetailScreen({super.key, required this.flagId});

  final String flagId;

  @override
  ConsumerState<FlaggedRecordDetailScreen> createState() => _FlaggedRecordDetailScreenState();
}

class _FlaggedRecordDetailScreenState extends ConsumerState<FlaggedRecordDetailScreen> {
  bool _isSubmitting = false;

  Future<void> _resolve() async {
    final notesController = TextEditingController();
    var showError = false;
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppFormDialog(title: 'Mark as reviewed', submitLabel: 'Mark as reviewed', onSubmit: () {
                final trimmed = notesController.text.trim();
                if (trimmed.isEmpty) {
                  setDialogState(() => showError = true);
                  return;
                }
                Navigator.pop(context, trimmed);
              }, child: TextField(
            controller: notesController,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Resolution notes',
              errorText: showError ? 'Resolution notes are required' : null,
            ),
            onChanged: (_) {
              if (showError) setDialogState(() => showError = false);
            },
          ),),
      ),
    );
    if (notes == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(adminRepositoryProvider).resolveFlaggedRecord(widget.flagId, resolutionNotes: notes);
      ref.invalidate(adminFlaggedRecordsProvider);
      if (mounted) {
        AppToast.success(context, 'Flagged record resolved.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not resolve this record.', error: e);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flagsAsync = ref.watch(adminFlaggedRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Flagged record')),
      body: flagsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(message: 'Could not load this flagged record.', onRetry: () => ref.invalidate(adminFlaggedRecordsProvider)),
        data: (flags) {
          final matches = flags.where((f) => f.flagId == widget.flagId);
          final flag = matches.isEmpty ? null : matches.first;
          if (flag == null) {
            return const EmptyState(icon: Icons.search_off_outlined, title: 'Flagged record not found', message: 'It may have been removed, or the link is out of date. Go back and try again.');
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(flag.citizenDisplayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    StatusBadge.fromStatus(flag.status),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow(label: 'Reason', value: flag.reason),
                    DetailRow(label: 'Raised', value: AppFormatters.date(flag.raisedAt)),
                    DetailRow(label: 'Notes', value: flag.resolutionNotes ?? 'No notes yet'),
                  ],
                ),
              ),
              if (flag.citizenId != null) ...[
                const SizedBox(height: 20),
                AppButton(
                  label: "Manage this citizen's account",
                  icon: Icons.manage_accounts_outlined,
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  onPressed: () => context.push('${AppRoutes.adminUsers}/${flag.citizenId}'),
                ),
              ],
              if (flag.status != 'resolved') ...[
                const SizedBox(height: 12),
                AppButton(
                  label: 'Mark as reviewed',
                  icon: Icons.fact_check_outlined,
                  expand: true,
                  loading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _resolve,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
