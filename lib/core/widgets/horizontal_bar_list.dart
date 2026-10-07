import 'package:flutter/material.dart';

/// Labelled horizontal bars scaled to the largest value -- shared by the
/// admin analytics screen and the department dashboard's "Records by
/// service" breakdown.
class HorizontalBarList extends StatelessWidget {
  const HorizontalBarList({super.key, required this.data, this.labelWidth = 110});

  final List<(String, int)> data;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (data.isEmpty) {
      return const SizedBox(height: 60, child: Center(child: Text('No data yet.')));
    }
    final maxValue = data.map((e) => e.$2).fold(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final (label, value) in data)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxValue == 0 ? 0 : value / maxValue,
                      minHeight: 14,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(scheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text('$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
