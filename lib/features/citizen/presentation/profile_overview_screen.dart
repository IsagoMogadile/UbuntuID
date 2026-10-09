import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/accessibility_link.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../routing/app_routes.dart';
import '../../../services/service_providers.dart';
import '../data/citizen_repository.dart';

class ProfileOverviewScreen extends ConsumerWidget {
  const ProfileOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(digitalIdentityProvider);
    final email = ref.watch(authServiceProvider).currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: identityAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => const ErrorView(message: 'Could not load your profile.'),
        data: (identity) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(identity.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(email ?? identity.email ?? ''),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Account'),
            Hero(
              tag: 'digital-id-card-hero',
              child: ListItemCard(
                title: 'Digital ID card',
                subtitle: 'QR code for in-person identity verification',
                leadingIcon: Icons.qr_code_2_outlined,
                onTap: () => context.push(AppRoutes.citizenDigitalIdCard),
              ),
            ),
            const SizedBox(height: 10),
            ListItemCard(
              title: 'Personal information',
              subtitle: 'Name, ID number, contact details',
              leadingIcon: Icons.badge_outlined,
              onTap: () => context.push(AppRoutes.citizenPersonalInformation),
            ),
            const SizedBox(height: 10),
            ListItemCard(
              title: 'Verification consent',
              subtitle: 'Which organisations can verify your credentials',
              leadingIcon: Icons.privacy_tip_outlined,
              onTap: () => context.push(AppRoutes.citizenConsent),
            ),
            const AccessibilityProfileLink(),
          ],
        ),
      ),
    );
  }
}
