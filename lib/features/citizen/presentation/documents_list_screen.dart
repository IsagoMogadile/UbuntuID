import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/citizen_repository.dart';
import '../documents/document_downloads.dart';
import '../domain/credential_item.dart';
import '../domain/digital_identity.dart';

/// The citizen's one place for documents: every downloadable prototype PDF
/// (identity document front & back, plus one per credential they hold),
/// then the documents on file in UbuntuID.
class DocumentsListScreen extends ConsumerWidget {
  const DocumentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(digitalIdentityProvider);
    final credentialsAsync = ref.watch(credentialsProvider);
    final documentsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(credentialsProvider)
            ..invalidate(documentsProvider);
          await ref.read(credentialsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'Downloadable documents'),
            Text(
              'Prototype PDFs for demonstration only - not real government documents.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            identityAsync.when(
              loading: () => const SizedBox(
                height: 180,
                child: ShimmerListPlaceholder(itemCount: 3, padding: EdgeInsets.zero),
              ),
              error: (error, _) => ErrorView(
                message: 'Could not load your identity.',
                onRetry: () => ref.invalidate(digitalIdentityProvider),
              ),
              data: (identity) => _DownloadableDocuments(identity: identity, credentialsAsync: credentialsAsync),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Documents on file'),
            documentsAsync.when(
              loading: () => const SizedBox(
                height: 120,
                child: ShimmerListPlaceholder(itemCount: 2, padding: EdgeInsets.zero),
              ),
              error: (error, _) => ErrorView(
                message: 'Could not load your documents.',
                onRetry: () => ref.invalidate(documentsProvider),
              ),
              data: (documents) {
                if (documents.isEmpty) {
                  return const AppCard(child: Text('No other documents are on file for you yet.'));
                }
                return Column(
                  children: [
                    for (final document in documents)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ListItemCard(
                          title: document.documentType,
                          subtitle: '${document.fileName} • ${AppFormatters.date(document.createdAt)}',
                          leadingIcon: Icons.description_outlined,
                          trailing: StatusBadge.fromStatus(document.status),
                          onTap: () => context.push('${AppRoutes.citizenDocuments}/${document.documentId}'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadableDocuments extends ConsumerWidget {
  const _DownloadableDocuments({required this.identity, required this.credentialsAsync});

  final DigitalIdentity identity;
  final AsyncValue<List<CredentialItem>> credentialsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentials = credentialsAsync.value ?? const <CredentialItem>[];

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _DownloadTile(
            icon: Icons.badge_outlined,
            title: 'Identity document',
            subtitle: 'Front and back (2 pages) • Department of Home Affairs',
            onDownload: () => DocumentDownloads.identityDocument(context, ref, identity),
          ),
          if (credentialsAsync.isLoading && credentials.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator())
          else if (credentialsAsync.hasError)
            ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Could not load your credentials.'),
              trailing: TextButton(
                onPressed: () => ref.invalidate(credentialsProvider),
                child: const Text('Retry'),
              ),
            )
          else
            for (final credential in credentials) ...[
              const Divider(height: 1),
              _DownloadTile(
                icon: _iconFor(credential.typeCode),
                title: credential.typeName,
                subtitle: '${credential.issuingDepartment} • Issued ${AppFormatters.date(credential.issuedDate)}',
                status: credential.status,
                onDownload: () => DocumentDownloads.credential(context, ref, identity, credential),
              ),
            ],
        ],
      ),
    );
  }

  static IconData _iconFor(String typeCode) => switch (typeCode) {
        'DRIVERS_LICENCE' => Icons.directions_car_outlined,
        'PASSPORT' => Icons.flight_outlined,
        'NSC' || 'TERTIARY_QUALIFICATION' => Icons.school_outlined,
        'TAX_COMPLIANCE' => Icons.account_balance_outlined,
        'CRIMINAL_CLEARANCE' => Icons.verified_user_outlined,
        'LABOUR_STATUS' => Icons.work_outline,
        'SASSA_STATUS' => Icons.volunteer_activism_outlined,
        _ => Icons.description_outlined,
      };
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onDownload,
    this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? status;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onDownload,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status != null) ...[StatusBadge.fromStatus(status!), const SizedBox(width: 4)],
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Download PDF',
            onPressed: onDownload,
          ),
        ],
      ),
    );
  }
}
