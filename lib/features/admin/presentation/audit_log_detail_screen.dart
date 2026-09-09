import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/admin_repository.dart';
import 'audit_logs_list_screen.dart' show actorTypeLabel;

class AuditLogDetailScreen extends ConsumerWidget {
  const AuditLogDetailScreen({super.key, required this.logId});

  final String logId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(adminAuditLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit event')),
      body: logsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => const ErrorView(message: 'Could not load this audit event.'),
        data: (logs) {
          final matches = logs.where((l) => l.logId == logId);
          final log = matches.isEmpty ? null : matches.first;
          if (log == null) {
            return const EmptyState(icon: Icons.search_off_outlined, title: 'Audit event not found');
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow(label: 'Action', value: log.action),
                    DetailRow(
                      label: 'Responsible',
                      value: log.actorName ?? actorTypeLabel(log.actorType),
                    ),
                    DetailRow(label: 'Actor type', value: log.actorType),
                    DetailRow(label: 'Related table', value: log.relatedTable),
                    DetailRow(label: 'Occurred', value: AppFormatters.dateTime(log.occurredAt)),
                    DetailRow(label: 'IP address', value: log.ipAddress ?? 'Unknown'),
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
