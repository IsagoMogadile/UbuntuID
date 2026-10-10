import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/report_export.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/list_search_field.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/app_routes.dart';
import '../data/admin_repository.dart';
import '../domain/audit_log_item.dart';

/// `actor_type = 'system'` (seed data, database triggers) has no resolvable
/// name -- shown as "System" rather than left blank.
String actorTypeLabel(String actorType) => switch (actorType) {
      'system' => 'System',
      'department_official' => 'Department official',
      'administrator' => 'Administrator',
      'citizen' => 'Citizen',
      'organisation_user' => 'Organisation user',
      _ => actorType,
    };

/// Turns `action` (a raw `<insert|update|delete>_<table>` machine string
/// from `fn_audit_log`, or a named event such as `feedback_submitted`) plus
/// [AuditLogItem.metadata]/[AuditLogItem.targetCitizenName] into a plain
/// English sentence. Events without specific wording fall back to a generic
/// "Added/Updated/Removed a ..." sentence built from the table name.
String friendlyAuditAction(AuditLogItem log) {
  final target = log.targetCitizenName;
  final meta = log.metadata;
  final forTarget = target == null ? '' : ' for $target';
  switch (log.action) {
    case 'update_organisations':
      final status = meta?['registration_status'] as String?;
      return switch (status) {
        'revoked' => 'Revoked an organisation\'s access',
        'approved' => 'Approved an organisation',
        'declined' => 'Declined an organisation\'s application',
        _ => 'Updated an organisation\'s details',
      };
    case 'insert_organisations':
      return 'Registered a new organisation';
    case 'insert_verification_requests':
      return 'Requested verification$forTarget';
    case 'update_verification_requests':
      final status = meta?['overall_status'] as String?;
      final subject = target == null ? 'A verification request' : '$target\'s verification request';
      return switch (status) {
        null => 'Updated a verification request',
        'completed' || 'verified' || 'approved' => '$subject was completed',
        'failed' || 'rejected' => '$subject was unsuccessful',
        'cancelled' => '$subject was cancelled',
        'pending' => '$subject is awaiting review',
        _ => '$subject is now ${_humanise(status)}',
      };
    case 'application_replaced':
      return target == null
          ? 'Replaced an earlier application with a new one'
          : 'Replaced an earlier application for $target with a new one';
    case 'insert_organisation_employees':
      final title = meta?['job_title'] as String?;
      final who = target ?? 'a citizen';
      return title == null ? 'Offered a job to $who' : 'Offered $who a job as $title';
    case 'update_organisation_employees':
      final status = meta?['employment_status'] as String?;
      final who = target ?? 'an employee';
      return switch (status) {
        'active' || 'accepted' || 'employed' => '${_capitalise(who)} started employment',
        'declined' => '${_capitalise(who)} declined a job offer',
        'cancelled' || 'withdrawn' => 'Withdrew a job offer to $who',
        'terminated' || 'ended' || 'resigned' => 'Ended employment for $who',
        _ => 'Updated employment details for $who',
      };
    case 'delete_organisation_employees':
      return 'Removed ${target ?? 'an employee'} from the organisation';
    case 'feedback_submitted':
      return 'Submitted feedback';
    case 'feedback_status_updated':
      final status = meta?['status'] as String?;
      return status == null ? 'Updated the status of feedback' : 'Marked feedback as ${_humanise(status)}';
    case 'insert_credentials':
      return 'Issued a credential$forTarget';
    case 'update_credentials':
      return 'Updated a credential$forTarget';
    case 'delete_credentials':
      return 'Removed a credential$forTarget';
  }

  final match = RegExp(r'^(insert|update|delete)_(.+)$').firstMatch(log.action);
  if (match == null) return _capitalise(_humanise(log.action));
  final verb = switch (match.group(1)) {
    'insert' => 'Added',
    'update' => 'Updated',
    _ => 'Removed',
  };
  final record = _recordNames[match.group(2)] ?? _humanise(match.group(2)!);
  return '$verb ${_article(record)} $record$forTarget';
}

/// Singular, plain-English names for audited tables.
const _recordNames = <String, String>{
  'appeals': 'appeal',
  'citizen_addresses': 'citizen address',
  'citizen_feedback': 'feedback entry',
  'citizens': 'citizen profile',
  'compliance_audits': 'compliance audit',
  'consent_grants': 'consent grant',
  'credential_types': 'credential type',
  'credentials': 'credential',
  'dbe_nsc_results': 'matric result',
  'department_officials': 'department official',
  'departments': 'department',
  'dha_marital_records': 'marital record',
  'dha_passports': 'passport record',
  'dhet_academic_records': 'academic record',
  'dhet_student_enrollment': 'student enrolment',
  'documents': 'document',
  'dot_driver_licences': 'driver\'s licence',
  'dot_vehicles': 'vehicle record',
  'flagged_records': 'flagged record',
  'housing_applications': 'housing application',
  'housing_beneficiaries': 'housing beneficiary',
  'housing_programmes': 'housing programme',
  'human_settlements_records': 'human settlements record',
  'notifications': 'notification',
  'organisation_credential_scopes': 'organisation credential permission',
  'organisation_employees': 'employment record',
  'organisation_users': 'organisation user',
  'organisations': 'organisation',
  'properties': 'property record',
  'saps_clearance_certificates': 'police clearance certificate',
  'saps_criminal_records': 'criminal record',
  'saps_wanted_persons': 'wanted person record',
  'sars_tax_returns': 'tax return',
  'sars_taxpayers': 'taxpayer record',
  'sassa_grants': 'social grant',
  'title_deeds': 'title deed',
  'ubuntuid_administrators': 'administrator',
  'verification_requests': 'verification request',
  'verification_results': 'verification result',
};

String _humanise(String value) => value.replaceAll('_', ' ').trim();

String _capitalise(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

String _article(String noun) => 'aeiou'.contains(noun[0].toLowerCase()) ? 'an' : 'a';

class AuditLogsListScreen extends ConsumerStatefulWidget {
  const AuditLogsListScreen({super.key});

  @override
  ConsumerState<AuditLogsListScreen> createState() => _AuditLogsListScreenState();
}

class _AuditLogsListScreenState extends ConsumerState<AuditLogsListScreen> {
  String _query = '';

  // The live feed this reads from (streamAuditLogs) caps at the 200 most
  // recent events by design (an unbounded realtime stream isn't a good
  // idea) -- exporting exactly what's loaded means a large audit trail
  // silently only gets you the newest 200 rows, so say so explicitly
  // rather than let an admin assume this is the complete history.
  Future<void> _exportExcel(WidgetRef ref) async {
    final logs = ref.read(adminAuditLogsProvider).value ?? const [];
    await ReportExport.exportExcel(
      filename: 'UbuntuID_Audit_Logs_Last_200.xlsx',
      title: 'Audit logs',
      subtitle: 'Most recent 200 events',
      headers: const ['Action', 'Responsible', 'Related table', 'Occurred', 'IP address'],
      rows: [
        for (final log in logs)
          [
            log.action,
            log.actorName ?? actorTypeLabel(log.actorType),
            log.relatedTable,
            AppFormatters.dateTime(log.occurredAt),
            log.ipAddress ?? '',
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(adminAuditLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export last 200 events as Excel',
            onPressed: () => _exportExcel(ref),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load audit logs.',
          onRetry: () => ref.invalidate(adminAuditLogsProvider),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No audit events yet', message: 'Every sign-in, verification and change to a record will be listed here.');
          }

          final shown = _query.isEmpty
              ? logs
              : logs.where((log) {
                  final responsible = log.actorName ?? actorTypeLabel(log.actorType);
                  return '${friendlyAuditAction(log)} $responsible ${log.relatedTable}'.toLowerCase().contains(_query);
                }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: ListSearchField(
                  hintText: 'Search by action, person or record type',
                  onChanged: (q) => setState(() => _query = q),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Showing ${shown.length} of the ${logs.length} most recent events',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off_outlined,
                        title: 'No events match',
                        message: 'Try a different search.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final log = shown[index];
                          final responsible = log.actorName ?? actorTypeLabel(log.actorType);
                          return ListItemCard(
                            title: friendlyAuditAction(log),
                            subtitle: '$responsible • ${AppFormatters.dateTime(log.occurredAt)}',
                            leadingIcon: Icons.receipt_long_outlined,
                            onTap: () => context.push('${AppRoutes.adminAudit}/${log.logId}'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
