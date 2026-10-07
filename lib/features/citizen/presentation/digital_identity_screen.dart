import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
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
  const DigitalIdentityScreen({super.key, this.filterTypeCode, this.title});

  /// When set (a Services tile other than Home Affairs), the screen shows
  /// only this one department's credential -- not the full identity
  /// overview -- and says so plainly ("No data") if the citizen doesn't
  /// have one. `null` for the Home Affairs tile, which keeps the full,
  /// unfiltered view below (the citizen's own identity details are
  /// themselves Home Affairs' civil-registry data).
  final String? filterTypeCode;

  /// AppBar title when [filterTypeCode] is set (the Services tile's own
  /// name, e.g. "Driver's Licence"). Falls back to "Digital Identity".
  final String? title;

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
    final filterTypeCode = this.filterTypeCode;

    return Scaffold(
      appBar: AppBar(title: Text(filterTypeCode != null ? (title ?? 'Digital Identity') : 'Digital Identity')),
      body: identityAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load your digital identity.',
          onRetry: () => ref.invalidate(digitalIdentityProvider),
        ),
        data: (identity) => filterTypeCode != null
            ? _FilteredCredentialView(
                identity: identity,
                credentialsAsync: credentialsAsync,
                typeCode: filterTypeCode,
                title: title ?? 'Digital Identity',
              )
            : ListView(
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
                            trailing: StatusBadge.fromStatus(credentials[i].status),
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

/// The Services screen's per-department view -- everything but that one
/// department's own credential is left out entirely, and "No data" is
/// shown plainly rather than an empty generic list when the citizen
/// doesn't have one.
class _FilteredCredentialView extends StatelessWidget {
  const _FilteredCredentialView({
    required this.identity,
    required this.credentialsAsync,
    required this.typeCode,
    required this.title,
  });

  final DigitalIdentity identity;
  final AsyncValue<List<CredentialItem>> credentialsAsync;
  final String typeCode;
  final String title;

  @override
  Widget build(BuildContext context) {
    return credentialsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (error, _) => const ErrorView(message: 'Could not load this record.'),
      data: (credentials) {
        final matches = credentials.where((c) => c.typeCode == typeCode).toList();
        if (matches.isEmpty) {
          return EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No data',
            message: '$title has no record on file for you.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < matches.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(matches[i].typeName),
                      subtitle: Text(DigitalIdentityScreen._credentialSubtitle(matches[i])),
                      isThreeLine: matches[i].qualification != null,
                      trailing: StatusBadge.fromStatus(matches[i].status),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
