import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/report_export.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
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

/// Turns `action` (a raw `<insert|update|delete>_<table>` machine string,
/// via `fn_audit_log`) plus [AuditLogItem.metadata]/[AuditLogItem.targetCitizenName]
/// into a human sentence for the handful of actions this session added
/// deliberately readable handling for. Everything else falls back to the
/// raw label rather than fabricating a sentence for tables this wasn't
/// written to understand -- honest partial coverage, not a full audit-log
/// rewrite.
String friendlyAuditAction(AuditLogItem log) {
  final target = log.targetCitizenName;
  final meta = log.metadata;
  switch (log.action) {
    case 'update_organisations':
      final status = meta?['registration_status'] as String?;
      return switch (status) {
        'revoked' => 'Revoked an organisation\'s access',
        'approved' => 'Approved an organisation',
        'declined' => 'Declined an organisation\'s application',
        _ => 'Updated an organisation',
      };
    case 'insert_organisations':
      return 'Registered an organisation';
    case 'insert_verification_requests':
      return target == null ? 'Submitted a verification request' : 'Submitted a verification request for $target';
    case 'update_verification_requests':
      final status = meta?['overall_status'] as String?;
      if (status == null) return 'Updated a verification request';
      final subject = target == null ? 'A verification request' : 'A verification request for $target';
      return '$subject was marked ${status.replaceAll('_', ' ')}';
    case 'insert_organisation_employees':
      final title = meta?['job_title'] as String?;
      final who = target ?? 'a citizen';
      return title == null ? 'Offered employment to $who' : 'Offered $who employment as $title';
    default:
      return log.action;
  }
}

class AuditLogsListScreen extends ConsumerWidget {
  const AuditLogsListScreen({super.key});

  // The live feed this reads from (streamAuditLogs) caps at the 200 most
  // recent events by design (an unbounded realtime stream isn't a good
  // idea) -- exporting exactly what's loaded means a large audit trail
  // silently only gets you the newest 200 rows, so say so explicitly
  // rather than let an admin assume this is the complete history.
  Future<void> _exportCsv(WidgetRef ref) async {
    final logs = ref.read(adminAuditLogsProvider).value ?? const [];
    await ReportExport.exportCsv(
      filename: 'ubuntuid_audit_logs_last_200.csv',
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
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(adminAuditLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export last 200 events as CSV',
            onPressed: () => _exportCsv(ref),
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
            return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No audit events yet');
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final log = logs[index];
              final responsible = log.actorName ?? actorTypeLabel(log.actorType);
              return ListItemCard(
                title: friendlyAuditAction(log),
                subtitle: '$responsible • ${AppFormatters.dateTime(log.occurredAt)}',
                leadingIcon: Icons.receipt_long_outlined,
                onTap: () => context.push('${AppRoutes.adminAudit}/${log.logId}'),
              );
            },
          );
        },
      ),
    );
  }
}
