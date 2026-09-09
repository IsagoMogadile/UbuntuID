import 'package:flutter/material.dart';

/// Counts up from 0 to [value] whenever it first builds or [value] changes,
/// instead of the number just appearing -- used on dashboard stat cards.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({super.key, required this.value, this.style, this.prefix = '', this.suffix = ''});

  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(value),
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) => Text('$prefix${animatedValue.round()}$suffix', style: style),
    );
  }
}
