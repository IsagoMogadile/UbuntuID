import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/staggered_fade_in.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/citizen_repository.dart';
import 'identity_card.dart';

class CitizenDashboardScreen extends ConsumerWidget {
  const CitizenDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(digitalIdentityProvider);
    final documentsAsync = ref.watch(documentsProvider);
    final notifications = ref.watch(notificationsControllerProvider).value ?? const [];
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // The ID card, QR code and all, front and centre the
        // moment a citizen lands here after logging in -- not buried a
        // couple of taps deep. Tapping it opens the full Document Wallet
        // (every credential, same card treatment, swipeable).
        identityAsync.when(
          loading: () => const SizedBox(height: 260, child: LoadingIndicator()),
          error: (error, _) => const ErrorView(message: 'Could not load your digital identity.'),
          data: (identity) => GestureDetector(
            onTap: () => context.push(AppRoutes.citizenDocumentWallet),
            child: IdentityCard(identity: identity, footerNote: 'Tap to open your Document Wallet.'),
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Verification status'),
        AppCard(
          child: const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AppColors.success),
              SizedBox(width: 12),
              Expanded(child: Text('Your identity has been verified with Home Affairs.')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'My activity'),
        ListItemCard(
          title: 'My Activity Report',
          subtitle: 'Your credentials, verification checks and history',
          leadingIcon: Icons.assessment_outlined,
          onTap: () => context.go(AppRoutes.citizenReports),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Quick actions'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _QuickAction(
              icon: Icons.qr_code_2_outlined,
              label: 'Document Wallet',
              onTap: () => context.push(AppRoutes.citizenDocumentWallet),
            ),
            _QuickAction(
              icon: Icons.badge_outlined,
              label: 'Digital ID',
              onTap: () => context.push(AppRoutes.citizenDigitalIdentity),
            ),
            _QuickAction(
              icon: Icons.description_outlined,
              label: 'Documents',
              onTap: () => context.push(AppRoutes.citizenDocuments),
            ),
            _QuickAction(
              icon: Icons.timeline_outlined,
              label: 'Timeline',
              onTap: () => context.push(AppRoutes.citizenTimeline),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Notifications',
          action: TextButton(
            onPressed: () => context.go(AppRoutes.citizenNotifications),
            child: Text(unreadCount > 0 ? 'View all ($unreadCount new)' : 'View all'),
          ),
        ),
        for (final (i, n) in notifications.take(2).indexed)
          StaggeredFadeIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListItemCard(
                title: n.message,
                subtitle: n.channel.toUpperCase(),
                leadingIcon: Icons.notifications_outlined,
                trailing: n.isRead ? null : const _UnreadDot(),
                onTap: () => context.go('${AppRoutes.citizenNotifications}/${n.notificationId}'),
              ),
            ),
          ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Recent activity'),
        documentsAsync.when(
          loading: () => const ShimmerListPlaceholder(itemCount: 2, padding: EdgeInsets.zero),
          error: (error, _) => const ErrorView(message: 'Could not load recent activity.'),
          data: (documents) => Column(
            children: [
              for (final (i, d) in documents.take(2).indexed)
                StaggeredFadeIn(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ListItemCard(
                      title: d.documentType,
                      subtitle: d.fileName,
                      leadingIcon: Icons.description_outlined,
                      trailing: StatusBadge.fromStatus(d.status),
                      onTap: () => context.push('${AppRoutes.citizenDocuments}/${d.documentId}'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            // Always reserve two lines so a one-line label ("Timeline") gives
            // the same tile height as one that wraps ("Document Wallet").
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(32),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
    );
  }
}
