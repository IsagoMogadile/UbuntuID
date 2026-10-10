import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/overview_strip.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../../reports/domain/report_data.dart';
import '../../reports/presentation/report_activity_card.dart';
import '../data/organisation_repository.dart';
import '../domain/organisation_dashboard_stats.dart';
import 'resubmit_organisation_sheet.dart';
import '../../../core/utils/friendly_error.dart';

class OrganisationDashboardScreen extends ConsumerWidget {
  const OrganisationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(organisationApplicationStatusProvider);
    final statsAsync = ref.watch(organisationDashboardStatsProvider);

    return statusAsync.when(
      loading: () => const LoadingIndicator(),
      error: (error, _) => ErrorView(
        message: 'Could not load your organisation.',
        onRetry: () => ref.invalidate(organisationApplicationStatusProvider),
      ),
      data: (status) {
        if (status.registrationStatus != 'approved') {
          return _PendingOrDeclinedView(status: status);
        }
        return statsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 92, child: ShimmerStatCardsPlaceholder(count: 2)),
                SizedBox(height: 20),
                Expanded(child: ShimmerListPlaceholder(itemCount: 4, padding: EdgeInsets.zero)),
              ],
            ),
          ),
          error: (error, _) => ErrorView(
            message: 'Could not load dashboard.\n\nDEBUG. ${friendlyError(error)}',
            onRetry: () => ref.invalidate(organisationDashboardStatsProvider),
          ),
          data: (stats) => _buildDashboard(context, ref, stats),
        );
      },
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, OrganisationDashboardStats stats) {
    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: Text(stats.organisationName, style: Theme.of(context).textTheme.titleLarge)),
              StatusBadge.fromStatus(stats.verified ? 'verified' : 'revoked'),
            ],
          ),
          if (!stats.verified) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.gpp_maybe_outlined, color: AppColors.warning),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Your organisation's verification has been revoked by UbuntuID, so you can't add applicants "
                      'or verify anyone right now. Your past results are still here. Contact UbuntuID to have it restored.',
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const SectionHeader(title: 'Overview'),
          OverviewStrip(
            items: [
              OverviewItem(
                label: 'Pending applicants',
                value: stats.pendingVerifications,
                icon: Icons.hourglass_top_outlined,
                onTap: () => context.go(AppRoutes.organisationVerification),
              ),
              OverviewItem(
                label: 'Reviewed this month',
                value: stats.completedThisMonth,
                icon: Icons.task_alt_outlined,
                onTap: () => context.go(AppRoutes.organisationVerification),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            onTap: () => context.push(AppRoutes.organisationEmployees),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.badge_outlined),
              title: Text('Employees'),
              subtitle: Text('People you employed through UbuntuID – view or end an employment'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 20),
          const ReportActivityCard(kind: ReportKind.organisation, reportRoute: AppRoutes.organisationReports),
        ],
    );
  }
}

class _PendingOrDeclinedView extends ConsumerStatefulWidget {
  const _PendingOrDeclinedView({required this.status});

  final OrganisationApplicationStatus status;

  @override
  ConsumerState<_PendingOrDeclinedView> createState() => _PendingOrDeclinedViewState();
}

class _PendingOrDeclinedViewState extends ConsumerState<_PendingOrDeclinedView> {
  Future<void> _resubmit() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ResubmitOrganisationSheet(organisationId: widget.status.organisationId),
    );
    if (done == true) {
      ref.invalidate(organisationApplicationStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final declined = widget.status.registrationStatus == 'declined';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              declined ? Icons.cancel_outlined : Icons.hourglass_top_outlined,
              size: 56,
              color: declined ? AppColors.error : AppColors.warning,
            ),
            const SizedBox(height: 16),
            Text(
              declined ? 'Application declined' : 'Application pending review',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              declined
                  ? (widget.status.declineReason?.isNotEmpty == true
                      ? widget.status.declineReason!
                      : 'A UbuntuID administrator declined this application.')
                  : '${widget.status.legalName} is awaiting review by a UbuntuID administrator. '
                      'You\'ll be able to verify citizens once your organisation is approved.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.charcoalMuted),
            ),
            if (declined && widget.status.isHead) ...[
              const SizedBox(height: 20),
              AppButton(label: 'Resubmit application', icon: Icons.refresh, onPressed: _resubmit),
            ],
          ],
        ),
      ),
    );
  }
}
