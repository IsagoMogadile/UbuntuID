import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../routing/app_routes.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Data sharing'),
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Organisation consent'),
              subtitle: const Text('Review organisations you have granted verification access to'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.citizenConsent),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'UbuntuID records each verification request an organisation or '
            'department makes against your digital identity. A full consent '
            'and access-history log will appear here.',
            style: TextStyle(color: AppColors.charcoalMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
