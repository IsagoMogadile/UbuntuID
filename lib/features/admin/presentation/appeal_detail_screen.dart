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
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_form_dialog.dart';

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
        AppToast.error(context, 'Could not start review.', error: e);
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
        builder: (context, setDialogState) => AppFormDialog(title: uphold ? 'Uphold this appeal?' : 'Reject this appeal?', submitLabel: uphold ? 'Uphold' : 'Reject', onSubmit: () {
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
              labelText: 'Decision notes',
              errorText: showError ? 'Decision notes are required' : null,
            ),
            onChanged: (_) {
              if (showError) setDialogState(() => showError = false);
            },
          ),),
      ),
    );
    if (notes == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(adminRepositoryProvider).decideAppeal(appealId: widget.appealId, uphold: uphold, decisionNotes: notes);
      ref.invalidate(adminAppealsProvider);
      if (mounted) {
        AppToast.success(context, uphold ? 'Appeal upheld.' : 'Appeal rejected.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not record this decision.', error: e);
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
        error: (error, _) => ErrorView(message: 'Could not load this appeal.', onRetry: () => ref.invalidate(adminAppealsProvider)),
        data: (appeals) {
          final matches = appeals.where((a) => a.appealId == widget.appealId);
          final appeal = matches.isEmpty ? null : matches.first;
          if (appeal == null) {
            return const EmptyState(icon: Icons.search_off_outlined, title: 'Appeal not found', message: 'It may have been removed, or the link is out of date. Go back and try again.');
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
                    DetailRow(label: 'About', value: appealSubject(appeal.relatedTable)),
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

/// What an appeal is about, in words: the record type it was lodged
/// against, or a general appeal (lodged against the citizen themselves).
String appealSubject(String relatedTable) => switch (relatedTable) {
      'citizens' => 'General – not about one specific record',
      'dha_marital_records' => 'Marriage record',
      'dha_death_records' => 'Death record',
      'dha_passports' => 'Passport',
      'dha_immigration_records' => 'Immigration record',
      'dot_driver_licences' => "Driver's licence",
      'dot_vehicles' => 'Vehicle registration',
      'sars_taxpayers' => 'Taxpayer registration',
      'sars_tax_returns' => 'Tax return',
      'saps_criminal_records' => 'Criminal record',
      'saps_clearance_certificates' => 'Police clearance certificate',
      'dbe_nsc_results' => 'Matric certificate',
      'dhet_student_enrollment' => 'Student enrolment',
      'dhet_academic_records' => 'Academic record',
      'dhet_nsfas_funding' => 'NSFAS funding',
      'sassa_grants' => 'SASSA grant',
      'labour_employment_records' => 'Employment / UIF record',
      'properties' => 'Property',
      'title_deeds' => 'Title deed',
      'housing_applications' => 'Housing application',
      _ => relatedTable.replaceAll('_', ' '),
    };
