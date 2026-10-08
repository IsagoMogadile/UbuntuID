import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/user_role.dart';
import '../../../routing/app_routes.dart';
import '../../../services/service_providers.dart';
import '../../auth/application/logout.dart';

class SettingsHomeScreen extends ConsumerWidget {
  const SettingsHomeScreen({super.key, this.showLogout = true});

  /// False where the surrounding navigation already has its own "Log Out"
  /// destination (the department official shell), so it isn't offered twice.
  final bool showLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCitizen = ref.watch(currentRoleProvider).value?.role == UserRole.citizen;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Preferences'),
          ListItemCard(
            title: 'Account',
            subtitle: 'Email and password',
            leadingIcon: Icons.person_outline,
            onTap: () => context.push(AppRoutes.settingsAccount),
          ),
          const SizedBox(height: 10),
          ListItemCard(
            title: 'Security',
            subtitle: 'Sign-in and device security',
            leadingIcon: Icons.security_outlined,
            onTap: () => context.push(AppRoutes.settingsSecurity),
          ),
          const SizedBox(height: 10),
          ListItemCard(
            title: 'Notifications',
            subtitle: 'How UbuntuID contacts you',
            leadingIcon: Icons.notifications_outlined,
            onTap: () => context.push(AppRoutes.settingsNotifications),
          ),
          const SizedBox(height: 10),
          ListItemCard(
            title: 'Privacy',
            subtitle: 'Consent and data sharing',
            leadingIcon: Icons.privacy_tip_outlined,
            onTap: () => context.push(AppRoutes.settingsPrivacy),
          ),
          const SizedBox(height: 10),
          ListItemCard(
            title: 'Appearance',
            subtitle: 'Light, dark, or match your device',
            leadingIcon: Icons.dark_mode_outlined,
            onTap: () => context.push(AppRoutes.settingsAppearance),
          ),
          const SizedBox(height: 10),
          if (isCitizen) ...[
            ListItemCard(
              title: 'Feedback',
              subtitle: 'Complaints, compliments and suggestions',
              leadingIcon: Icons.feedback_outlined,
              onTap: () => context.push(AppRoutes.citizenFeedback),
            ),
            const SizedBox(height: 10),
          ],
          ListItemCard(
            title: 'About UbuntuID',
            leadingIcon: Icons.info_outline,
            onTap: () => context.push(AppRoutes.settingsAbout),
          ),
          if (showLogout) ...[
            const SizedBox(height: 24),
            ListItemCard(
              title: 'Log out',
              leadingIcon: Icons.logout,
              onTap: () => confirmAndLogOut(context, ref),
              trailing: const SizedBox.shrink(),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
