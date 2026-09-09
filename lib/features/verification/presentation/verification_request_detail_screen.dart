import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/verification_repository.dart';

// Matches the live `verification_status_check` constraint's open/in-flight
// values -- 'in_review' is not a valid `overall_status` value (confirmed
// live), 'processing' is.
const _openStatuses = {'pending', 'processing'};

/// Shared detail body used by the department official, organisation and
/// administrator "Verification request" screens. Approve/reject are only
/// offered to department officials/admins (organisations raise requests,
/// they don't decide them) and only while the request is still open.
class VerificationRequestDetailScreen extends ConsumerStatefulWidget {
  const VerificationRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<VerificationRequestDetailScreen> createState() => _VerificationRequestDetailScreenState();
}

class _VerificationRequestDetailScreenState extends ConsumerState<VerificationRequestDetailScreen> {
  bool _isSubmitting = false;

  Future<void> _decide(bool approve) async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(verificationRepositoryProvider).decide(widget.requestId, approve: approve);
      ref.invalidate(verificationRequestDetailProvider(widget.requestId));
      ref.invalidate(verificationRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Request approved.' : 'Request rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record this decision: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(verificationRequestDetailProvider(widget.requestId));
    final resultsAsync = ref.watch(verificationResultLinesProvider(widget.requestId));
    final canDecideAsync = ref.watch(canDecideVerificationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verification request')),
      body: requestAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load this request.',
          onRetry: () => ref.invalidate(verificationRequestDetailProvider(widget.requestId)),
        ),
        data: (request) {
          final canDecide = (canDecideAsync.value ?? false) && _openStatuses.contains(request.overallStatus);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionHeader(title: 'Citizen identity summary'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow(label: 'Citizen', value: request.citizenDisplayName),
                    DetailRow(label: 'Requested by', value: request.organisationName),
                    DetailRow(label: 'Requested', value: AppFormatters.dateTime(request.requestedAt)),
                    DetailRow(
                      label: 'Responded',
                      value: request.respondedAt == null
                          ? 'Awaiting response'
                          : AppFormatters.dateTime(request.respondedAt!),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 150, child: Text('Status')),
                          StatusBadge.fromStatus(request.overallStatus),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Verification results'),
              resultsAsync.when(
                loading: () => const LoadingIndicator(),
                error: (error, _) => const ErrorView(message: 'Could not load verification results.'),
                data: (results) => results.isEmpty
                    ? const AppCard(child: Text('No credential checks recorded for this request yet.'))
                    : AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < results.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            results[i].credentialTypeName,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Claimed: ${results[i].claimedValue}'),
                                          Text('Verified: ${results[i].verifiedValue}'),
                                        ],
                                      ),
                                    ),
                                    StatusBadge.fromStatus(results[i].matchStatus),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
              if (canDecide) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Approve',
                        icon: Icons.check_circle_outline,
                        loading: _isSubmitting,
                        onPressed: _isSubmitting ? null : () => _decide(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: 'Reject',
                        icon: Icons.cancel_outlined,
                        variant: AppButtonVariant.secondary,
                        loading: _isSubmitting,
                        onPressed: _isSubmitting ? null : () => _decide(false),
                      ),
                    ),
                  ],
                ),
              ] else if (!_openStatuses.contains(request.overallStatus)) ...[
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'This request has already been decided.',
                    style: TextStyle(color: AppColors.charcoalMuted),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
