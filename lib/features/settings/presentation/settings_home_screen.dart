import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../routing/app_routes.dart';
import '../../../services/service_providers.dart';

class SettingsHomeScreen extends ConsumerWidget {
  const SettingsHomeScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out of UbuntuID?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(authServiceProvider).signOut();
    if (context.mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          ListItemCard(
            title: 'About UbuntuID',
            leadingIcon: Icons.info_outline,
            onTap: () => context.push(AppRoutes.settingsAbout),
          ),
          const SizedBox(height: 24),
          ListItemCard(
            title: 'Log out',
            leadingIcon: Icons.logout,
            onTap: () => _confirmLogout(context, ref),
            trailing: const SizedBox.shrink(),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
