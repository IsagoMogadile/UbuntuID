import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
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
          error: (error, _) => ErrorView(message: 'Could not load your digital identity.', onRetry: () => ref.invalidate(digitalIdentityProvider)),
          data: (identity) => GestureDetector(
            onTap: () => context.push(AppRoutes.citizenDocumentWallet),
            child: IdentityCard(identity: identity, footerNote: 'Tap to open your Document Wallet.'),
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Identity status'),
        identityAsync.maybeWhen(
          data: (identity) => _IdentityStatusCard(status: identity.currentStatus),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Quick actions'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _QuickAction(
              icon: Icons.description_outlined,
              label: 'Documents',
              onTap: () => context.push(AppRoutes.citizenDocuments),
            ),
            _QuickAction(
              icon: Icons.fact_check_outlined,
              label: 'Who checked my details',
              onTap: () => context.push(AppRoutes.citizenVerification),
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
      ],
    );
  }
}
/// Authored by Buhle Ndlovu, Kopano Mogadile, Keamogetswe Molefane  : A quick action tile on the citizen dashboard, with an icon and a label. Tapping it performs the given action.

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

/// The citizen's identity status in words, with what to do when it isn't
/// active -- rather than always claiming the identity is verified.
class _IdentityStatusCard extends StatelessWidget {
  const _IdentityStatusCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String message) = switch (status) {
      'active' => (Icons.verified_user_outlined, AppColors.success, 'Your identity is verified with Home Affairs.'),
      'suspended' => (
          Icons.pause_circle_outline,
          AppColors.warning,
          'Your identity is suspended. Organisations cannot verify your details until Home Affairs reactivates it. '
              'Visit a Home Affairs office to resolve this.',
        ),
      _ => (Icons.info_outline, AppColors.info, 'Your identity status is "$status". Contact Home Affairs if this is wrong.'),
    };
    return AppCard(
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          const SizedBox(width: 8),
          StatusBadge.fromStatus(status),
        ],
      ),
    );
  }
}
