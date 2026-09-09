import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../routing/app_routes.dart';
import '../../../services/service_providers.dart';

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Sign-in security'),
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Two-factor authentication'),
              subtitle: const Text('Coming soon'),
              value: false,
              onChanged: null,
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'This device'),
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.smartphone_outlined),
              title: const Text('Current session'),
              subtitle: const Text('Active now'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out of all devices'),
          ),
        ],
      ),
    );
  }
}
