import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routing/app_routes.dart';
import '../../../services/service_providers.dart';

/// Looks up the signed-in user's real role via [RoleService] and returns the
/// route they should land on. Returns [AppRoutes.login] if nobody is signed
/// in, or [AppRoutes.accountNotConfigured] if the auth user has no matching
/// row in any of the role tables yet.
Future<String> resolveDestinationRoute(WidgetRef ref) async {
  final user = ref.read(authServiceProvider).currentUser;
  if (user == null) return AppRoutes.login;

  final roleService = ref.read(roleServiceProvider);
  var result = await roleService.detectRole(user.id);

  if (result == null) {
    // No role row yet -- this may be a citizen created by a Home Affairs
    // official (their `citizens` row already exists, with this email, but
    // was never linked to a login) signing in for the first time. Try to
    // claim it before giving up.
    final claimed = await roleService.claimCitizenAccount();
    if (claimed) {
      result = await roleService.detectRole(user.id);
    }
  }

  if (result == null) return AppRoutes.accountNotConfigured;

  final blockedReason = await roleService.checkAccountActive(result);
  if (blockedReason != null) {
    await ref.read(authServiceProvider).signOut();
    return '${AppRoutes.accountRevoked}?reason=${Uri.encodeComponent(blockedReason)}';
  }

  return AppRoutes.dashboardForRole(result.role);
}
