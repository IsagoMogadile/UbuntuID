import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/feedback_repository.dart';
import '../domain/feedback_item.dart';
import '../../../core/widgets/app_toast.dart';

/// Administrator review of one piece of citizen feedback: set it to
/// acknowledged / under investigation / resolved and optionally type a
/// response. Saving notifies the citizen.
class AdminFeedbackDetailScreen extends ConsumerStatefulWidget {
  const AdminFeedbackDetailScreen({super.key, required this.feedbackId});

  final String feedbackId;

  @override
  ConsumerState<AdminFeedbackDetailScreen> createState() => _AdminFeedbackDetailScreenState();
}

class _AdminFeedbackDetailScreenState extends ConsumerState<AdminFeedbackDetailScreen> {
  final _responseController = TextEditingController();
  String? _status;
  bool _submitting = false;

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final status = _status;
    if (status == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(feedbackRepositoryProvider).updateFeedback(
            feedbackId: widget.feedbackId,
            status: status,
            response: _responseController.text.trim().isEmpty ? null : _responseController.text.trim(),
          );
      ref.invalidate(adminFeedbackProvider);
      if (!mounted) return;
      _responseController.clear();
      AppToast.success(context, 'Feedback marked ${feedbackLabel(status).toLowerCase()}. The citizen has been notified.');
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not update feedback.', error: e);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedbackAsync = ref.watch(adminFeedbackProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: feedbackAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(message: 'Could not load this feedback.', onRetry: () => ref.invalidate(adminFeedbackProvider)),
        data: (items) {
          final matches = items.where((f) => f.feedbackId == widget.feedbackId);
          final item = matches.isEmpty ? null : matches.first;
          if (item == null) {
            return const EmptyState(icon: Icons.search_off_outlined, title: 'Feedback not found', message: 'It may have been removed, or the link is out of date. Go back and try again.');
          }
          _status ??= item.status == 'submitted' ? 'acknowledged' : item.status;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${feedbackLabel(item.feedbackType)} • ${item.subjectLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    StatusBadge.fromStatus(item.status),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow(label: 'From', value: item.citizenDisplayName ?? 'Unknown citizen'),
                    DetailRow(label: 'Submitted', value: AppFormatters.dateTime(item.createdAt)),
                    DetailRow(
                      label: 'System rating',
                      value: item.rating == null ? 'Not rated' : '${'★' * item.rating!} (${item.rating}/5)',
                    ),
                    DetailRow(label: 'Feedback', value: item.message),
                    if (item.adminResponse != null) DetailRow(label: 'Last response', value: item.adminResponse!),
                    if (item.respondedAt != null)
                      DetailRow(label: 'Last updated', value: AppFormatters.dateTime(item.respondedAt!)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Update status'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<String>(
                      segments: [
                        for (final s in feedbackAdminStatuses) ButtonSegment(value: s, label: Text(feedbackLabel(s))),
                      ],
                      selected: {_status!},
                      onSelectionChanged: (s) => setState(() => _status = s.first),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _responseController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Response to the citizen (optional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Save and notify citizen',
                      icon: Icons.check,
                      expand: true,
                      loading: _submitting,
                      onPressed: _submitting ? null : _save,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
