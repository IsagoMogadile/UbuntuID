import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/feedback_repository.dart';
import '../domain/feedback_item.dart';
import '../../../core/widgets/app_toast.dart';

/// Citizen-only (Settings > Feedback): a complaint, compliment or
/// suggestion about one department or UbuntuID in general, plus an
/// optional system rating. Below the form, the citizen's past feedback with
/// the administrator's status and response.
class GiveFeedbackScreen extends ConsumerStatefulWidget {
  const GiveFeedbackScreen({super.key});

  @override
  ConsumerState<GiveFeedbackScreen> createState() => _GiveFeedbackScreenState();
}

class _GiveFeedbackScreenState extends ConsumerState<GiveFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _type = 'complaint';
  String? _departmentId; // null = UbuntuID in general
  int? _rating;
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(feedbackRepositoryProvider).submitFeedback(
            feedbackType: _type,
            message: _messageController.text.trim(),
            departmentId: _departmentId,
            rating: _rating,
          );
      ref.invalidate(myFeedbackProvider);
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _rating = null;
        _departmentId = null;
        _type = 'complaint';
      });
      AppToast.success(context, 'Thank you. Your feedback has been sent to the UbuntuID administrators.');
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not send feedback.', error: e);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(feedbackDepartmentsProvider).value ?? const [];
    final myFeedbackAsync = ref.watch(myFeedbackProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tell us about your experience. Only UbuntuID administrators can see your feedback.',
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: [
                      for (final type in feedbackTypes)
                        ButtonSegment(value: type, label: Text(feedbackLabel(type))),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() => _type = s.first),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _departmentId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'About'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('UbuntuID in general')),
                      for (final d in departments) DropdownMenuItem(value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (v) => setState(() => _departmentId = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageController,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 2000,
                    decoration: const InputDecoration(labelText: 'Your feedback', alignLabelWithHint: true),
                    validator: (v) =>
                        (v == null || v.trim().length < 5) ? 'Please describe your feedback (at least 5 characters).' : null,
                  ),
                  const SizedBox(height: 8),
                  Text('How would you rate UbuntuID? (optional)', style: Theme.of(context).textTheme.bodyMedium),
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          tooltip: '$i star${i == 1 ? '' : 's'}',
                          icon: Icon(
                            (_rating ?? 0) >= i ? Icons.star : Icons.star_border,
                            color: Colors.amber.shade700,
                          ),
                          onPressed: () => setState(() => _rating = _rating == i ? null : i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Send feedback',
                    icon: Icons.send_outlined,
                    expand: true,
                    loading: _submitting,
                    onPressed: _submitting ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'My feedback'),
          myFeedbackAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Text('Could not load your previous feedback.'),
            data: (items) => items.isEmpty
                ? const Text('You have not sent any feedback yet.')
                : Column(
                    children: [
                      for (final item in items) ...[
                        _MyFeedbackCard(item: item),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MyFeedbackCard extends StatelessWidget {
  const _MyFeedbackCard({required this.item});

  final FeedbackItem item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: 6),
          Text(AppFormatters.date(item.createdAt), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(item.message),
          if (item.adminResponse != null) ...[
            const SizedBox(height: 10),
            Text('Response from UbuntuID', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(item.adminResponse!),
          ],
        ],
      ),
    );
  }
}
