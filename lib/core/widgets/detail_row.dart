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
    final labelText = Text(label, style: TextStyle(color: mutedColor));
    final valueText = Text(value, style: const TextStyle(fontWeight: FontWeight.w500));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Side by side when there's room for it; on narrow screens (or
          // with large text) the label sits above its value instead.
          final labelWidth = 150 * MediaQuery.textScalerOf(context).scale(1);
          if (constraints.maxWidth < labelWidth * 2.4) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [labelText, const SizedBox(height: 2), valueText],
                  ),
                ),
                ?trailing,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: labelWidth, child: labelText),
              Expanded(child: valueText),
              ?trailing,
            ],
          );
        },
      ),
    );
  }
}
