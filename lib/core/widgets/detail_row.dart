import 'package:flutter/material.dart';

/// A `label: value` row used throughout detail screens.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // `onSurfaceVariant` is the theme's muted-text token -- already
    // balanced per brightness in AppTheme (charcoalMuted in light, a
    // light muted green-grey in dark), unlike a fixed AppColors constant.
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: TextStyle(color: mutedColor)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
          ?trailing,
        ],
      ),
    );
  }
}
