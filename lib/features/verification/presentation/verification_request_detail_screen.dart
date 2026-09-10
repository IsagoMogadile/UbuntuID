import 'dart:async';

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
import '../../organisation/data/organisation_repository.dart';
import '../data/verification_repository.dart';

/// How long the simulated automated check runs for, with a progress UI,
/// before `complete_verification` is called. This project has no
/// background job scheduler -- see docs/KNOWN_LIMITATIONS.md -- so the
/// "automated processing time" is a real client-side wait rather than a
/// true server-side async job; the comparison itself is genuinely
/// automated and un-skippable from the UI either way.
const _processingWait = Duration(seconds: 18);

const _openStatuses = {'pending', 'processing'};
const _terminalStatuses = {'completed', 'partially_verified', 'failed', 'rejected', 'cancelled'};

/// Terminal statuses that reflect an actual review outcome (as opposed to
/// 'cancelled', which means no review happened at all). Hiring is the
/// organisation's own call -- they can still offer employment after
/// reviewing an applicant even if the check came back partial or failed,
/// so "Offer employment" is gated on this set, not just 'completed'.
const _reviewedStatuses = {'completed', 'partially_verified', 'failed', 'rejected'};

/// Shared detail body used by the department official, organisation and
/// administrator "Verification request" screens.
///
/// Nobody manually decides a verification any more (see
/// docs/database/automated_verification_and_org_revocation.sql) -- the
/// requesting organisation starts it, the system does the actual
/// claimed-vs-verified comparison, and the organisation acknowledges the
/// result once. After that acknowledgement, re-opening this screen (for
/// the organisation specifically) shows only the final status, not the
/// per-credential detail -- a fresh look needs a new request. Department
/// officials, administrators and the citizen themselves always see full
/// detail; only the requesting organisation's own re-view is restricted.
class VerificationRequestDetailScreen extends ConsumerStatefulWidget {
  const VerificationRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<VerificationRequestDetailScreen> createState() => _VerificationRequestDetailScreenState();
}

class _VerificationRequestDetailScreenState extends ConsumerState<VerificationRequestDetailScreen> {
  bool _starting = false;
  bool _acknowledging = false;
  bool _autoProcessTriggered = false;
  Timer? _tickTimer;
  int _secondsElapsed = 0;

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _invalidateAll() {
    ref.invalidate(verificationRequestDetailProvider(widget.requestId));
    ref.invalidate(verificationResultLinesProvider(widget.requestId));
    ref.invalidate(verificationRequestsProvider);
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      await ref.read(verificationRepositoryProvider).startVerification(widget.requestId);
      _invalidateAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start this check: $e')));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Fired once (guarded by [_autoProcessTriggered]) whenever this screen
  /// is showing a 'processing' request it owns -- runs the progress
  /// countdown, then calls `complete_verification`. Triggered from build()
  /// rather than initState() because whether it should run at all depends
  /// on data that's only known once the request/ownership providers
  /// resolve.
  void _beginAutoProcessing() {
    if (_autoProcessTriggered) return;
    _autoProcessTriggered = true;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsElapsed++);
      if (_secondsElapsed >= _processingWait.inSeconds) {
        timer.cancel();
        _finishProcessing();
      }
    });
  }

  Future<void> _finishProcessing() async {
    try {
      await ref.read(verificationRepositoryProvider).completeVerification(widget.requestId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not complete this check: $e')));
      }
    }
    if (mounted) _invalidateAll();
  }

  Future<void> _offerEmployment(String citizenId) async {
    final titleController = TextEditingController();
    final positionController = TextEditingController();
    final salaryController = TextEditingController();
    var salaryFrequency = 'Monthly';
    var startDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Offer employment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Job title'),
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: positionController,
                  decoration: const InputDecoration(labelText: 'Department/position (optional)'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: salaryController,
                        decoration: const InputDecoration(labelText: 'Salary (R, optional)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: salaryFrequency,
                      items: const [
                        DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'Annual', child: Text('Annual')),
                      ],
                      onChanged: (v) => setDialogState(() => salaryFrequency = v ?? 'Monthly'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Start date: ${AppFormatters.date(startDate)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => startDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Offer')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A job title is required.')));
      return;
    }

    try {
      final result = await ref.read(organisationRepositoryProvider).offerEmployment(
            citizenId: citizenId,
            jobTitle: titleController.text.trim(),
            departmentOrPosition: positionController.text.trim().isEmpty ? null : positionController.text.trim(),
            salary: num.tryParse(salaryController.text.trim()),
            salaryFrequency: salaryFrequency,
            startDate: startDate,
            sourceVerificationRequestId: widget.requestId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            result.labourRecorded
                ? 'Employment offer created. Department of Labour\'s official record now shows this citizen as employed.'
                : 'Employment offer created. ${result.skipReason ?? "Department of Labour's official record was not updated."}',
          ),
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create this offer: $e')));
      }
    }
  }

  Future<void> _acknowledge() async {
    setState(() => _acknowledging = true);
    try {
      await ref.read(verificationRepositoryProvider).acknowledgeResult(widget.requestId);
      _invalidateAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not complete this: $e')));
      }
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(verificationRequestDetailProvider(widget.requestId));
    final orgIdAsync = ref.watch(currentOrganisationIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verification request')),
      body: requestAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load this request.',
          onRetry: () => ref.invalidate(verificationRequestDetailProvider(widget.requestId)),
        ),
        data: (request) {
          final isOwningOrg = orgIdAsync.value != null && orgIdAsync.value == request.organisationId;

          if (isOwningOrg && request.overallStatus == 'processing') {
            WidgetsBinding.instance.addPostFrameCallback((_) => _beginAutoProcessing());
          }

          // The organisation's own view of a request it has already
          // acknowledged -- summary only, no per-credential detail.
          final isRedactedForOrg =
              isOwningOrg && _terminalStatuses.contains(request.overallStatus) && request.orgViewedAt != null;

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
                    if (request.processingStartedAt != null)
                      DetailRow(label: 'Review started', value: AppFormatters.dateTime(request.processingStartedAt!)),
                    DetailRow(
                      label: 'Completed',
                      value: request.respondedAt == null
                          ? 'Not yet completed'
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

              if (isOwningOrg && request.overallStatus == 'pending') ...[
                const _InfoBanner(
                  icon: Icons.info_outline,
                  message: 'This starts an automated check -- UbuntuID compares what was claimed against the '
                      'real department records. No official reviews this manually.',
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Start review',
                  icon: Icons.play_circle_outline,
                  expand: true,
                  loading: _starting,
                  onPressed: _starting ? null : _start,
                ),
              ] else if (request.overallStatus == 'processing') ...[
                _ProcessingCard(
                  secondsElapsed: isOwningOrg ? _secondsElapsed : null,
                  totalSeconds: _processingWait.inSeconds,
                ),
              ] else if (isRedactedForOrg) ...[
                const _InfoBanner(
                  icon: Icons.visibility_off_outlined,
                  message: 'You\'ve already viewed this result. Submit a new verification request to see the '
                      'comparison again.',
                ),
                if (_reviewedStatuses.contains(request.overallStatus) && request.citizenId != null) ...[
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Offer employment',
                    icon: Icons.business_center_outlined,
                    expand: true,
                    onPressed: () => _offerEmployment(request.citizenId!),
                  ),
                ],
              ] else ...[
                const SectionHeader(title: 'Verification results'),
                _ResultsList(requestId: widget.requestId),
                if (isOwningOrg && _reviewedStatuses.contains(request.overallStatus) && request.citizenId != null) ...[
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Offer employment',
                    icon: Icons.business_center_outlined,
                    expand: true,
                    onPressed: () => _offerEmployment(request.citizenId!),
                  ),
                ],
                if (isOwningOrg && _terminalStatuses.contains(request.overallStatus)) ...[
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Done',
                    icon: Icons.check_circle_outline,
                    variant: AppButtonVariant.secondary,
                    expand: true,
                    loading: _acknowledging,
                    onPressed: _acknowledging ? null : _acknowledge,
                  ),
                ],
              ],

              if (!isOwningOrg && !_openStatuses.contains(request.overallStatus)) ...[
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'This request has been completed by the automated verification check.',
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.charcoalMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.charcoalMuted))),
        ],
      ),
    );
  }
}

class _ProcessingCard extends StatelessWidget {
  const _ProcessingCard({required this.secondsElapsed, required this.totalSeconds});

  /// Null when this viewer isn't the owning organisation -- they still see
  /// that it's processing, just not a live countdown driven by this
  /// screen's own timer (only the organisation's screen runs the timer
  /// that actually calls `complete_verification`).
  final int? secondsElapsed;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final elapsed = secondsElapsed;
    final progress = elapsed == null ? null : (elapsed / totalSeconds).clamp(0.0, 1.0);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_top_outlined, size: 20),
              const SizedBox(width: 10),
              Text('Verifying against department records...', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress),
          if (elapsed != null) ...[
            const SizedBox(height: 8),
            Text(
              '${(totalSeconds - elapsed).clamp(0, totalSeconds)}s remaining',
              style: const TextStyle(color: AppColors.charcoalMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultsList extends ConsumerWidget {
  const _ResultsList({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(verificationResultLinesProvider(requestId));
    return resultsAsync.when(
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
    );
  }
}
