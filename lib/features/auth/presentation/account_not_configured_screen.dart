import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../routing/app_routes.dart';
import '../../../services/service_providers.dart';
import '../application/role_resolution.dart';

/// Shown when a Supabase auth account exists but has no matching row in
/// citizens / department_officials / organisation_users /
/// ubuntuid_administrators -- i.e. the account has not been linked to a
/// role yet.
class AccountNotConfiguredScreen extends ConsumerStatefulWidget {
  const AccountNotConfiguredScreen({super.key});

  @override
  ConsumerState<AccountNotConfiguredScreen> createState() => _AccountNotConfiguredScreenState();
}

class _AccountNotConfiguredScreenState extends ConsumerState<AccountNotConfiguredScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    try {
      final destination = await resolveDestinationRoute(ref);
      if (!mounted) return;
      if (destination != AppRoutes.accountNotConfigured) {
        context.go(destination);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still not linked to a role yet.')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

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
                  const Icon(Icons.person_search_outlined, size: 48, color: AppColors.gold),
                  const SizedBox(height: 16),
                  Text('Account not configured', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    "We couldn't link this account to a citizen, department "
                    'official, organisation or administrator record. If Home '
                    "Affairs already registered you as a citizen, make sure "
                    "you signed up with the exact same email address they "
                    'used for you -- that\'s what links your login to your '
                    'record automatically. If you confirmed your email to '
                    'register an organisation, finish that below. Otherwise, '
                    'contact your administrator to have your access '
                    'configured, then try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.charcoalMuted),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Finish registering your organisation',
                    icon: Icons.apartment_outlined,
                    onPressed: () => context.push(AppRoutes.registerOrganisation),
                    expand: true,
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Check again',
                    icon: Icons.refresh,
                    onPressed: _retry,
                    loading: _checking,
                    expand: true,
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Sign out',
                    variant: AppButtonVariant.text,
                    onPressed: _signOut,
                    expand: true,
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
