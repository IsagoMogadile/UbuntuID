import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../../services/service_providers.dart';

/// Asks for confirmation, signs out of Supabase and returns to the login
/// screen. Shared by Settings' "Log out" row and the department navigation's
/// "Log Out" destination. The router's redirect guard would send a signed-out
/// user on a protected route to login anyway; navigating explicitly just
/// avoids leaving them on a stale screen until the next navigation.
Future<void> confirmAndLogOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Log out'),
      content: const Text('Are you sure you want to log out of UbuntuID?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
      ],
    ),
  );

  if (confirmed != true) return;

  await ref.read(authServiceProvider).signOut();
  if (context.mounted) context.go(AppRoutes.login);
}
