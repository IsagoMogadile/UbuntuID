import 'package:flutter/material.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';

/// Local, unpersisted preference toggles -- there is no notification
/// preferences table in the current schema, so this screen is UI-only.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _email = true;
  bool _sms = true;
  bool _push = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Delivery channels'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Email'),
                  value: _email,
                  onChanged: (value) => setState(() => _email = value),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('SMS'),
                  value: _sms,
                  onChanged: (value) => setState(() => _sms = value),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Push notifications'),
                  value: _push,
                  onChanged: (value) => setState(() => _push = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
