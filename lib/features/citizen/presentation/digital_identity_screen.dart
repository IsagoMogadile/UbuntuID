import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/report_export.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/staggered_fade_in.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/citizen_repository.dart';
import '../domain/credential_item.dart';
import '../domain/digital_identity.dart';

class DigitalIdentityScreen extends ConsumerWidget {
  const DigitalIdentityScreen({super.key});

  Future<void> _downloadCredential(DigitalIdentity identity, CredentialItem credential) {
    final qualification = credential.qualification;
    return ReportExport.exportPdf(
      filename: '${credential.typeName.replaceAll(' ', '_').toLowerCase()}.pdf',
      title: credential.typeName,
      subtitle: '${identity.fullName} • ID ${identity.idNumber}',
      headers: const ['Field', 'Value'],
      rows: [
        ['Issuing department', credential.issuingDepartment],
        ['Status', credential.status],
        ['Issued', AppFormatters.date(credential.issuedDate)],
        ['Expiry', credential.expiryDate == null ? 'n/a' : AppFormatters.date(credential.expiryDate!)],
        if (credential.nqfLevel != null) ['NQF level', '${credential.nqfLevel}'],
        if (qualification != null) ...[
          ['Qualification', qualification.qualificationName],
          if (qualification.institutionName != null) ['Institution', qualification.institutionName!],
          if (qualification.year != null) ['Year', '${qualification.year}'],
          if (qualification.result != null) ['Result', qualification.result!],
        ],
      ],
    );
  }

  static String _credentialSubtitle(CredentialItem credential) {
    final qualification = credential.qualification;
    if (qualification != null) {
      final parts = [
        qualification.qualificationName,
        if (qualification.institutionName != null) qualification.institutionName!,
        if (qualification.result != null) qualification.result!,
      ];
      return parts.join(' • ');
    }
    return credential.nqfLevel == null
        ? credential.issuingDepartment
        : '${credential.issuingDepartment} • NQF ${credential.nqfLevel}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(digitalIdentityProvider);
    final credentialsAsync = ref.watch(credentialsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Identity')),
      body: identityAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load your digital identity.',
          onRetry: () => ref.invalidate(digitalIdentityProvider),
        ),
        data: (identity) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'Digital ID overview'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(identity.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      StatusBadge.fromStatus(identity.currentStatus),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('ID ${identity.idNumber}'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Personal information'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DetailRow(label: 'Full name', value: identity.fullName),
                  DetailRow(label: 'ID number', value: identity.idNumber),
                  DetailRow(label: 'Date of birth', value: AppFormatters.date(identity.dateOfBirth)),
                  DetailRow(label: 'Phone', value: identity.phoneNumber ?? 'Not on file'),
                  DetailRow(label: 'Email', value: identity.email ?? 'Not on file'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Identity verification status'),
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Registered ${AppFormatters.date(identity.registeredAt)} via Home Affairs',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Identity credentials'),
            credentialsAsync.when(
              loading: () => const SizedBox(height: 180, child: ShimmerListPlaceholder(itemCount: 3, padding: EdgeInsets.zero)),
              error: (error, _) => const ErrorView(message: 'Could not load credentials.'),
              data: (credentials) {
                if (credentials.isEmpty) {
                  return const EmptyState(
                    icon: Icons.badge_outlined,
                    title: 'No credentials or records available from this department.',
                  );
                }
                return AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < credentials.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        StaggeredFadeIn(
                          index: i,
                          child: ListTile(
                            title: Text(credentials[i].typeName),
                            subtitle: Text(_credentialSubtitle(credentials[i])),
                            isThreeLine: credentials[i].qualification != null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusBadge.fromStatus(credentials[i].status),
                                IconButton(
                                  icon: const Icon(Icons.download_outlined, size: 20),
                                  tooltip: 'Download',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () => _downloadCredential(identity, credentials[i]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: 'Verification requests',
              action: TextButton(
                onPressed: () => context.push(AppRoutes.citizenVerification),
                child: const Text('View all'),
              ),
            ),
            AppCard(
              onTap: () => context.push(AppRoutes.citizenVerification),
              child: const Row(
                children: [
                  Icon(Icons.fact_check_outlined),
                  SizedBox(width: 12),
                  Expanded(child: Text('See which organisations have requested to verify you')),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
