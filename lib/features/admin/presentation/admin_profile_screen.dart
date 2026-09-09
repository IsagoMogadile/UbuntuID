import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../routing/app_routes.dart';
import '../../../services/service_providers.dart';

class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authServiceProvider).currentUser?.email ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Administrator'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DetailRow(label: 'Email', value: email),
                const DetailRow(label: 'Role', value: 'UbuntuID Administrator'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Account'),
          ListItemCard(
            title: 'Settings',
            subtitle: 'Account, security, notifications, privacy',
            leadingIcon: Icons.settings_outlined,
            onTap: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
    );
  }
}
