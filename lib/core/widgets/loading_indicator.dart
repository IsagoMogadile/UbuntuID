import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLoadingBar(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// A slim, rounded, brand-coloured loading bar -- something simple to look
/// at while a screen waits on data, in place of a plain spinner. Built on
/// Flutter's own indeterminate `LinearProgressIndicator` animation (no
/// custom `AnimationController` needed), so it's as low-risk as a loading
/// widget gets while still being more on-brand than the default.
class AppLoadingBar extends StatelessWidget {
  const AppLoadingBar({super.key, this.width = 140});

  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: width,
        height: 6,
        child: LinearProgressIndicator(
          backgroundColor: AppColors.green.withValues(alpha: 0.15),
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
        ),
      ),
    );
  }
}
