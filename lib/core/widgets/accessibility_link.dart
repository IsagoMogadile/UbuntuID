import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/app_routes.dart';
import 'list_item_card.dart';
import 'section_header.dart';

/// The "Accessibility" entry at the foot of every account's profile.
class AccessibilityProfileLink extends StatelessWidget {
  const AccessibilityProfileLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const SectionHeader(title: 'Preferences'),
        const SizedBox(height: 8),
        ListItemCard(
          title: 'Accessibility',
          subtitle: 'Theme, text size, reduced motion and more',
          leadingIcon: Icons.accessibility_new_outlined,
          onTap: () => context.push(AppRoutes.settingsAccessibility),
        ),
      ],
    );
  }
}
