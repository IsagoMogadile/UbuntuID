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

class AuditLogsListScreen extends ConsumerWidget {
  const AuditLogsListScreen({super.key});

  Future<void> _exportCsv(WidgetRef ref) async {
    final logs = ref.read(adminAuditLogsProvider).value ?? const [];
    await ReportExport.exportCsv(
      filename: 'ubuntuid_audit_logs.csv',
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
          IconButton(icon: const Icon(Icons.download_outlined), tooltip: 'Export CSV', onPressed: () => _exportCsv(ref)),
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
                title: log.action,
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
