import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/accessibility_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/user_role.dart';
import '../../../services/service_providers.dart';

/// Theme, text size, reduced motion and (citizens) read aloud, from
/// Settings or any account's profile. Saved on this device.
class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilityControllerProvider);
    final controller = ref.read(accessibilityControllerProvider.notifier);
    final isCitizen = ref.watch(currentRoleProvider).value?.role == UserRole.citizen;
    final themeMode = ref.watch(themeModeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionHeader(title: 'Theme'),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: RadioGroup<ThemeMode>(
                  groupValue: themeMode,
                  onChanged: (mode) {
                    if (mode != null) ref.read(themeModeControllerProvider.notifier).setThemeMode(mode);
                  },
                  child: Column(
                    children: [
                      for (final (mode, label, description, icon) in const [
                        (ThemeMode.system, 'Match system', "Follow this device's setting", Icons.brightness_auto_outlined),
                        (ThemeMode.light, 'Light', 'Always use the light theme', Icons.light_mode_outlined),
                        (ThemeMode.dark, 'Dark', 'Always use the dark theme', Icons.dark_mode_outlined),
                      ]) ...[
                        if (mode != ThemeMode.system) const Divider(height: 1),
                        RadioListTile<ThemeMode>(
                          value: mode,
                          title: Text(label),
                          subtitle: Text(description),
                          secondary: Icon(icon),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Text size'),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in TextSizeOption.values)
                          ChoiceChip(
                            label: Text(option.label),
                            selected: settings.textSize == option,
                            onSelected: (_) => controller.setTextSize(option),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('This is how text will look across UbuntuID.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionHeader(title: isCitizen ? 'Motion and reading' : 'Motion'),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.motion_photos_off_outlined),
                      title: const Text('Reduce motion'),
                      subtitle: const Text('Turn off loading shimmer and animations'),
                      value: settings.reduceMotion,
                      onChanged: controller.setReduceMotion,
                    ),
                    if (isCitizen) ...[
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.volume_up_outlined),
                        title: const Text('Read aloud'),
                        subtitle: const Text(
                          'Tap anything once to hear it read out loud, then tap it again to use it',
                        ),
                        value: settings.readAloud,
                        onChanged: controller.setReadAloud,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Also supported'),
              const SizedBox(height: 8),
              const AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Note(
                      icon: Icons.record_voice_over_outlined,
                      text: 'Screen readers such as NVDA, JAWS, VoiceOver and TalkBack work across UbuntuID.',
                    ),
                    _Note(
                      icon: Icons.keyboard_outlined,
                      text: 'Keyboard: use Tab and Shift+Tab to move between controls, and Enter or Space to '
                          'press them. The selected control is highlighted.',
                    ),
                    _Note(
                      icon: Icons.timer_outlined,
                      text: 'You get a minute\'s warning before being signed out for inactivity, with a button to '
                          'stay signed in.',
                    ),
                    _Note(
                      icon: Icons.settings_accessibility_outlined,
                      text: 'Your device\'s own text size and reduce-motion settings are respected too.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.green),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
