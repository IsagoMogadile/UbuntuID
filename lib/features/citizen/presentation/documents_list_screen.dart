import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/citizen_repository.dart';

class DocumentsListScreen extends ConsumerWidget {
  const DocumentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: documentsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load your documents.',
          onRetry: () => ref.invalidate(documentsProvider),
        ),
        data: (documents) {
          if (documents.isEmpty) {
            return const EmptyState(
              icon: Icons.description_outlined,
              title: 'No documents on file',
              message: 'Documents associated with your identity will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final document = documents[index];
              return ListItemCard(
                title: document.documentType,
                subtitle: '${document.fileName} • ${AppFormatters.date(document.createdAt)}',
                leadingIcon: Icons.description_outlined,
                trailing: StatusBadge.fromStatus(document.status),
                onTap: () => context.push('${AppRoutes.citizenDocuments}/${document.documentId}'),
              );
            },
          );
        },
      ),
    );
  }
}
