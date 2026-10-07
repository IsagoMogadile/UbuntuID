import 'package:flutter/material.dart';

import 'animated_count.dart';
import 'app_card.dart';

class OverviewItem {
  const OverviewItem({required this.label, required this.value, required this.icon, this.onTap});

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback? onTap;
}

/// A dashboard's headline numbers in one compact card, shared by every
/// role's dashboard. When there's room for every item side by side it's a
/// single divided strip; otherwise it falls back to slim divided rows
/// (icon, label, number), so it never turns into a grid of oversized boxes.
class OverviewStrip extends StatelessWidget {
  const OverviewStrip({super.key, required this.items});

  final List<OverviewItem> items;

  static const _minCellWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final fitsInRow = constraints.maxWidth >= _minCellWidth * items.length;
        return AppCard(
          padding: EdgeInsets.zero,
          child: fitsInRow ? _buildRow(context) : _buildList(context),
        );
      },
    );
  }

  Widget _buildRow(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const VerticalDivider(width: 1),
            Expanded(child: _Cell(item: items[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _Row(item: items[i]),
        ],
      ],
    );
  }
}

const _countStyle = TextStyle(fontWeight: FontWeight.w800, fontSize: 20);

class _Cell extends StatelessWidget {
  const _Cell({required this.item});

  final OverviewItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(item.icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(item.label, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedCount(value: item.value, style: _countStyle),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});

  final OverviewItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(item.label)),
            AnimatedCount(value: item.value, style: _countStyle.copyWith(fontSize: 17)),
            SizedBox(
              width: 24,
              child: item.onTap == null ? null : const Icon(Icons.chevron_right, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
