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
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as reviewed'),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Resolution notes'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, notesController.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (notes == null || notes.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(adminRepositoryProvider).resolveFlaggedRecord(widget.flagId, resolutionNotes: notes);
      ref.invalidate(adminFlaggedRecordsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flagged record resolved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not resolve this record: $e')));
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
        error: (error, _) => const ErrorView(message: 'Could not load this flagged record.'),
        data: (flags) {
          final matches = flags.where((f) => f.flagId == widget.flagId);
          final flag = matches.isEmpty ? null : matches.first;
          if (flag == null) {
            return const EmptyState(icon: Icons.search_off_outlined, title: 'Flagged record not found');
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
