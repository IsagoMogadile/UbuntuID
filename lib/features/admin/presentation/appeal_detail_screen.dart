import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/admin_repository.dart';

class AppealDetailScreen extends ConsumerStatefulWidget {
  const AppealDetailScreen({super.key, required this.appealId});

  final String appealId;

  @override
  ConsumerState<AppealDetailScreen> createState() => _AppealDetailScreenState();
}

class _AppealDetailScreenState extends ConsumerState<AppealDetailScreen> {
  bool _submitting = false;

  Future<void> _startReview() async {
    setState(() => _submitting = true);
    try {
      await ref.read(adminRepositoryProvider).startAppealReview(widget.appealId);
      ref.invalidate(adminAppealsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start review: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _decide(bool uphold) async {
    final notesController = TextEditingController();
    var showError = false;
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(uphold ? 'Uphold this appeal?' : 'Reject this appeal?'),
          content: TextField(
            controller: notesController,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Decision notes',
              errorText: showError ? 'Decision notes are required' : null,
            ),
            onChanged: (_) {
              if (showError) setDialogState(() => showError = false);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final trimmed = notesController.text.trim();
                if (trimmed.isEmpty) {
                  setDialogState(() => showError = true);
                  return;
                }
                Navigator.pop(context, trimmed);
              },
              child: Text(uphold ? 'Uphold' : 'Reject'),
            ),
          ],
        ),
      ),
    );
    if (notes == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(adminRepositoryProvider).decideAppeal(appealId: widget.appealId, uphold: uphold, decisionNotes: notes);
      ref.invalidate(adminAppealsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uphold ? 'Appeal upheld.' : 'Appeal rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not record this decision: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appealsAsync = ref.watch(adminAppealsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Appeal')),
      body: appealsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => const ErrorView(message: 'Could not load this appeal.'),
        data: (appeals) {
          final matches = appeals.where((a) => a.appealId == widget.appealId);
          final appeal = matches.isEmpty ? null : matches.first;
          if (appeal == null) {
            return const EmptyState(icon: Icons.search_off_outlined, title: 'Appeal not found');
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${appeal.citizenDisplayName} • ${appeal.departmentName}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    StatusBadge.fromStatus(appeal.status),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow(label: 'Reason', value: appeal.appealReason),
                    DetailRow(label: 'Against record in', value: appeal.relatedTable),
                    DetailRow(label: 'Lodged by', value: appeal.lodgedByName ?? 'Unknown official'),
                    DetailRow(label: 'Submitted', value: AppFormatters.dateTime(appeal.submittedAt)),
                    if (appeal.decision != null) ...[
                      DetailRow(label: 'Decision', value: appeal.decision!),
                      DetailRow(
                        label: 'Decided',
                        value: appeal.decisionDate == null ? '' : AppFormatters.date(appeal.decisionDate!),
                      ),
                      DetailRow(label: 'Decision notes', value: appeal.decisionNotes ?? ''),
                    ],
                  ],
                ),
              ),
              if (appeal.status == 'submitted') ...[
                const SizedBox(height: 20),
                AppButton(
                  label: 'Start review',
                  icon: Icons.visibility_outlined,
                  expand: true,
                  loading: _submitting,
                  onPressed: _submitting ? null : _startReview,
                ),
              ],
              if (appeal.status == 'submitted' || appeal.status == 'under_review') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Uphold',
                        icon: Icons.check_circle_outline,
                        expand: true,
                        loading: _submitting,
                        onPressed: _submitting ? null : () => _decide(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: 'Reject',
                        icon: Icons.cancel_outlined,
                        variant: AppButtonVariant.secondary,
                        expand: true,
                        loading: _submitting,
                        onPressed: _submitting ? null : () => _decide(false),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
