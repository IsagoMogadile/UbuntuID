import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../routing/app_routes.dart';

class UnauthorizedScreen extends StatelessWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unauthorized')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_outlined, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('You do not have access', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Your account does not have permission to view this page.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.charcoalMuted),
              ),
              const SizedBox(height: 20),
              AppButton(label: 'Go to login', onPressed: () => context.go(AppRoutes.login)),
            ],
          ),
        ),
      ),
    );
  }
}
