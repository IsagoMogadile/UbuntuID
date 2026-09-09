import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// A shimmering placeholder for a screen that's still loading, used instead
/// of a plain spinner on higher-traffic list/dashboard screens.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height = 14, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

/// A column of shimmering rows shaped like [ListItemCard] -- a leading
/// circle plus two text lines and a small trailing shape.
class ShimmerListPlaceholder extends StatelessWidget {
  const ShimmerListPlaceholder({super.key, this.itemCount = 6, this.padding = const EdgeInsets.all(16)});

  final int itemCount;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.neutralBg,
      highlightColor: Colors.white,
      child: Padding(
        padding: padding,
        child: Column(
          children: [
            for (var index = 0; index < itemCount; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const ShimmerBox(width: 40, height: 40, radius: 20),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          ShimmerBox(width: 140),
                          SizedBox(height: 8),
                          ShimmerBox(width: 90, height: 11),
                        ],
                      ),
                    ),
                    const ShimmerBox(width: 50, height: 20, radius: 999),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A row of shimmering stat-card placeholders, matching the dashboards'
/// `_StatCard` shape.
class ShimmerStatCardsPlaceholder extends StatelessWidget {
  const ShimmerStatCardsPlaceholder({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.neutralBg,
      highlightColor: Colors.white,
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 92,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 22, height: 22, radius: 6),
                    Spacer(),
                    ShimmerBox(width: 40, height: 18),
                    SizedBox(height: 6),
                    ShimmerBox(width: 60, height: 10),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
