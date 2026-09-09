import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, this.featureName});

  final String? featureName;

  @override
  Widget build(BuildContext context) {
    final name = featureName ?? 'This feature';
    return Scaffold(
      appBar: AppBar(title: Text(featureName ?? 'Coming soon')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 48, color: AppColors.gold),
              const SizedBox(height: 16),
              Text('$name is coming soon', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                "We're still connecting this to live UbuntuID data.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.charcoalMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
