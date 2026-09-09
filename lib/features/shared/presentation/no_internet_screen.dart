import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_outlined, size: 48, color: AppColors.charcoalMuted),
              const SizedBox(height: 16),
              Text('No internet connection', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'UbuntuID needs an internet connection to reach Supabase. '
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.charcoalMuted),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                AppButton(label: 'Try again', icon: Icons.refresh, onPressed: onRetry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
