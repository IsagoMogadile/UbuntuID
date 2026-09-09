import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/citizen_repository.dart';

class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Document')),
      body: documentsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => const ErrorView(message: 'Could not load this document.'),
        data: (documents) {
          final matches = documents.where((d) => d.documentId == documentId);
          final document = matches.isEmpty ? null : matches.first;
          if (document == null) {
            return const EmptyState(icon: Icons.search_off_outlined, title: 'Document not found');
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(document.documentType, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(document.fileName),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Verification status'),
              AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status'),
                    StatusBadge.fromStatus(document.status),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Details'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow(label: 'Uploaded', value: AppFormatters.dateTime(document.createdAt)),
                    DetailRow(
                      label: 'Reviewed',
                      value: document.reviewedAt == null
                          ? 'Not yet reviewed'
                          : AppFormatters.dateTime(document.reviewedAt!),
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
