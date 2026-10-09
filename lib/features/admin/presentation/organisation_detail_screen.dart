import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/admin_repository.dart';
import '../domain/organisation_list_item.dart';
import '../domain/organisation_review_detail.dart';

class OrganisationDetailScreen extends ConsumerStatefulWidget {
  const OrganisationDetailScreen({super.key, required this.organisationId});

  final String organisationId;

  @override
  ConsumerState<OrganisationDetailScreen> createState() => _OrganisationDetailScreenState();
}

class _OrganisationDetailScreenState extends ConsumerState<OrganisationDetailScreen> {
  bool _isSubmitting = false;

  Future<void> _toggleVerified(OrganisationListItem organisation) async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setOrganisationVerified(organisation.organisationId, !organisation.verified);
      ref.invalidate(adminOrganisationsProvider);
      ref.invalidate(adminOrganisationReviewDetailProvider(organisation.organisationId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(organisation.verified ? 'Organisation unverified.' : 'Organisation verified.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update this organisation: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _revokeOrReinstate(OrganisationListItem organisation, {required bool revoke}) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(revoke ? 'Revoke access' : 'Reinstate access'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                revoke
                    ? 'This organisation\'s staff will lose data access and be signed out on their next login. This can be reversed later.'
                    : 'This restores the organisation to approved status. Its staff will be able to log in and access data again.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Reason (required)'),
                maxLines: 3,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(revoke ? 'Revoke' : 'Reinstate'),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (revoke) {
        await repo.revokeOrganisation(organisationId: organisation.organisationId, reason: reason);
      } else {
        await repo.reinstateOrganisation(organisationId: organisation.organisationId, reason: reason);
      }
      ref.invalidate(adminOrganisationsProvider);
      ref.invalidate(adminOrganisationReviewDetailProvider(organisation.organisationId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(revoke ? 'Organisation access revoked.' : 'Organisation access reinstated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not complete this action: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _review(OrganisationListItem organisation, bool approve) async {
    String? notes;
    if (!approve) {
      notes = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Decline application'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Reason (shown to the organisation)'),
              maxLines: 3,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Decline'),
              ),
            ],
          );
        },
      );
      if (notes == null) return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(adminRepositoryProvider).reviewOrganisation(
            organisationId: organisation.organisationId,
            approve: approve,
            notes: notes,
          );
      ref.invalidate(adminOrganisationsProvider);
      ref.invalidate(adminOrganisationReviewDetailProvider(organisation.organisationId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Organisation approved.' : 'Organisation declined.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not review this organisation: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organisationsAsync = ref.watch(adminOrganisationsProvider);
    final detailAsync = ref.watch(adminOrganisationReviewDetailProvider(widget.organisationId));
    final detail = detailAsync.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Organisation')),
      body: organisationsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => const ErrorView(message: 'Could not load this organisation.'),
        data: (organisations) {
          final matches = organisations.where((o) => o.organisationId == widget.organisationId);
          final organisation = matches.isEmpty ? null : matches.first;
          if (organisation == null) {
            return const EmptyState(icon: Icons.search_off_outlined, title: 'Organisation not found');
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(organisation.legalName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    StatusBadge.fromStatus(organisation.registrationStatus),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow(label: 'Type', value: organisation.organisationType),
                    DetailRow(label: 'Registration no.', value: detail?.registrationNumber ?? '—'),
                    DetailRow(label: 'Access tier', value: organisation.accessTier),
                    DetailRow(label: 'Contact email', value: organisation.contactEmail),
                    DetailRow(
                      label: 'Contact phone',
                      value: (detail?.contactPhone ?? '').isEmpty ? '—' : detail!.contactPhone!,
                    ),
                    DetailRow(
                      label: 'Requested',
                      value: AppFormatters.date(detail?.requestedAt ?? organisation.registeredAt),
                    ),
                    if (detail?.reviewedAt != null)
                      DetailRow(label: 'Last reviewed', value: AppFormatters.dateTime(detail!.reviewedAt!)),
                    if (organisation.declineReason != null && organisation.declineReason!.isNotEmpty)
                      DetailRow(label: 'Decline reason', value: organisation.declineReason!),
                    if (organisation.revokedAt != null) ...[
                      DetailRow(label: 'Revoked', value: AppFormatters.dateTime(organisation.revokedAt!)),
                      DetailRow(label: 'Revoke reason', value: organisation.revokeReason ?? ''),
                    ],
                    if (organisation.reinstatedAt != null) ...[
                      DetailRow(label: 'Reinstated', value: AppFormatters.dateTime(organisation.reinstatedAt!)),
                      DetailRow(label: 'Reinstate reason', value: organisation.reinstateReason ?? ''),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...switch (detailAsync) {
                AsyncData(:final value) => _reviewSections(context, value),
                AsyncError() => [const Text('Could not load the full application details.'), const SizedBox(height: 20)],
                _ => [const LoadingIndicator(), const SizedBox(height: 20)],
              },
              if (organisation.registrationStatus == 'revoked')
                AppButton(
                  label: 'Reinstate access',
                  icon: Icons.replay_circle_filled_outlined,
                  expand: true,
                  loading: _isSubmitting,
                  onPressed: _isSubmitting ? null : () => _revokeOrReinstate(organisation, revoke: false),
                )
              else if (organisation.registrationStatus != 'approved') ...[
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Approve',
                        icon: Icons.check_circle_outline,
                        expand: true,
                        loading: _isSubmitting,
                        onPressed: _isSubmitting ? null : () => _review(organisation, true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: 'Decline',
                        icon: Icons.cancel_outlined,
                        variant: AppButtonVariant.secondary,
                        expand: true,
                        loading: _isSubmitting,
                        onPressed: _isSubmitting ? null : () => _review(organisation, false),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                AppButton(
                  label: 'Revoke verification',
                  icon: Icons.remove_circle_outline,
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  loading: _isSubmitting,
                  onPressed: _isSubmitting ? null : () => _toggleVerified(organisation),
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: 'Revoke access',
                  icon: Icons.block_outlined,
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  loading: _isSubmitting,
                  onPressed: _isSubmitting ? null : () => _revokeOrReinstate(organisation, revoke: true),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<Widget> _reviewSections(BuildContext context, OrganisationReviewDetail detail) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600);
    final heading = Theme.of(context).textTheme.titleSmall;
    return [
      Text('Why they need access', style: heading),
      const SizedBox(height: 8),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Purpose', style: muted),
            const SizedBox(height: 4),
            Text((detail.accessPurpose ?? '').isEmpty ? 'Not given (registered before reasons were asked for).' : detail.accessPurpose!),
            const Divider(height: 24),
            Text('Credentials requested (${detail.scopes.length})', style: muted),
            for (final scope in detail.scopes)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scope.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (scope.department.isNotEmpty) Text(scope.department, style: muted),
                    const SizedBox(height: 2),
                    Text((scope.reason ?? '').isEmpty ? 'No reason given.' : scope.reason!),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text('Registered by and staff', style: heading),
      const SizedBox(height: 8),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detail.staff.isEmpty) const Text('No staff accounts.'),
            for (final (i, person) in detail.staff.indexed) ...[
              if (i > 0) const Divider(height: 20),
              Row(
                children: [
                  Expanded(child: Text(person.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(person.active ? person.role : '${person.role} · inactive', style: muted),
                ],
              ),
              if ((person.email ?? '').isNotEmpty) Text(person.email!, style: muted),
              if ((person.idNumber ?? '').isNotEmpty) Text('ID ${person.idNumber}', style: muted),
            ],
          ],
        ),
      ),
      if (detail.history.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('Review history', style: heading),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, entry) in detail.history.indexed) ...[
                if (i > 0) const Divider(height: 20),
                Row(
                  children: [
                    StatusBadge.fromStatus(entry.status),
                    const Spacer(),
                    if (entry.at != null) Text(AppFormatters.dateTime(entry.at!), style: muted),
                  ],
                ),
                if ((entry.notes ?? '').isNotEmpty) ...[const SizedBox(height: 6), Text(entry.notes!)],
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 20),
    ];
  }
}
