import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'role_service.dart';
import 'supabase_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseService.client;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

final roleServiceProvider = Provider<RoleService>((ref) {
  return RoleService(ref.watch(supabaseClientProvider));
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Resolves the signed-in user's real role, re-querying whenever Supabase
/// emits an auth event (sign-in, sign-out, token refresh). This backs the
/// router's role-based access guard, preventing a logged-in user from
/// reaching another role's screens via a typed-in URL. RLS remains the
/// actual security boundary -- this is a UX/defence-in-depth guard, not a
/// replacement for it.
final currentRoleProvider = FutureProvider<RoleLookupResult?>((ref) async {
  ref.watch(authStateChangesProvider);
  final user = ref.watch(authServiceProvider).currentUser;
  if (user == null) return null;
  return ref.watch(roleServiceProvider).detectRole(user.id);
});
