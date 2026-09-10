import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../routing/app_routes.dart';

/// Shown after `RoleService.checkAccountActive` blocks a sign-in -- an
/// organisation revoked by an administrator, or a deactivated department
/// official. The session is already signed out by the time this renders
/// (see `resolveDestinationRoute`/`_resolveRoleAreaRedirect`).
class AccountRevokedScreen extends StatelessWidget {
  const AccountRevokedScreen({super.key, this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.block_outlined, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('Access revoked', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    reason ?? 'Your access to UbuntuID has been revoked.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.charcoalMuted),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Back to login',
                    icon: Icons.login,
                    expand: true,
                    onPressed: () => context.go(AppRoutes.login),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
