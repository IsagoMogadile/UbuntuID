import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Theme'),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final option in ThemeMode.values) ...[
                  if (option != ThemeMode.values.first) const Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    value: option,
                    // ignore: deprecated_member_use
                    groupValue: themeMode,
                    // ignore: deprecated_member_use
                    onChanged: (mode) {
                      if (mode != null) ref.read(themeModeControllerProvider.notifier).setThemeMode(mode);
                    },
                    title: Text(_label(option)),
                    subtitle: Text(_description(option)),
                    secondary: Icon(_icon(option)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Dark mode keeps UbuntuID's own green and gold identity -- it "
            "re-balances contrast for a dark surface rather than switching "
            'to a different colour scheme.',
            style: TextStyle(color: AppColors.charcoalMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _label(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Match system',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  String _description(ThemeMode mode) => switch (mode) {
        ThemeMode.system => "Follow this device's setting",
        ThemeMode.light => 'Always use the light theme',
        ThemeMode.dark => 'Always use the dark theme',
      };

  IconData _icon(ThemeMode mode) => switch (mode) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      };
}
