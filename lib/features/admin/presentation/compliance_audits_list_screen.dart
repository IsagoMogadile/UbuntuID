import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/report_export.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/admin_repository.dart';

class ComplianceAuditsListScreen extends ConsumerWidget {
  const ComplianceAuditsListScreen({super.key});

  Future<void> _exportPdf(WidgetRef ref) async {
    final audits = ref.read(adminComplianceAuditsProvider).value ?? const [];
    await ReportExport.exportPdf(
      filename: 'UbuntuID_Compliance_Audits.pdf',
      title: 'UbuntuID Compliance Audits',
      subtitle: '${audits.length} periodic rollup(s)',
      headers: const ['Period', 'Verification requests', 'Flagged records', 'Resolved', 'Generated'],
      rows: [
        for (final a in audits)
          [
            '${AppFormatters.date(a.periodStart)} - ${AppFormatters.date(a.periodEnd)}',
            '${a.totalVerificationRequests}',
            '${a.totalFlaggedRecords}',
            '${a.totalResolvedRecords}',
            AppFormatters.date(a.generatedAt),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditsAsync = ref.watch(adminComplianceAuditsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compliance Audits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF report',
            onPressed: () => _exportPdf(ref),
          ),
        ],
      ),
      body: auditsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load compliance audits.',
          onRetry: () => ref.invalidate(adminComplianceAuditsProvider),
        ),
        data: (audits) {
          if (audits.isEmpty) {
            return const EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'No compliance audits',
              message: 'No periodic compliance rollups have been generated yet.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: audits.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final audit = audits[index];
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppFormatters.date(audit.periodStart)} — ${AppFormatters.date(audit.periodEnd)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (audit.summary != null && audit.summary!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(audit.summary!),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Text('Verification requests: ${audit.totalVerificationRequests}'),
                        Text('Flagged records: ${audit.totalFlaggedRecords}'),
                        Text('Resolved: ${audit.totalResolvedRecords}'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Generated ${AppFormatters.date(audit.generatedAt)}'
                      '${audit.generatedByName != null ? ' by ${audit.generatedByName}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
