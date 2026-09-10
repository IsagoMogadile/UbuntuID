import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_role.dart';

class RoleLookupResult {
  const RoleLookupResult({required this.role, required this.identityId});

  final UserRole role;
  final String identityId;
}

class RoleService {
  RoleService(this._client);

  final SupabaseClient _client;

  // Table name -> (role, primary key column), confirmed against the live schema.
  static const _tablesByRole = {
    'citizens': (UserRole.citizen, 'citizen_id'),
    'department_officials': (UserRole.departmentOfficial, 'official_id'),
    'organisation_users': (UserRole.organisationUser, 'organisation_user_id'),
    'ubuntuid_administrators': (UserRole.administrator, 'admin_id'),
  };

  Future<RoleLookupResult?> detectRole(String authUserId) async {
    for (final entry in _tablesByRole.entries) {
      final (role, idColumn) = entry.value;
      final row = await _client
          .from(entry.key)
          .select(idColumn)
          .eq('auth_user_id', authUserId)
          .maybeSingle();

      if (row != null) {
        return RoleLookupResult(
          role: role,
          identityId: row[idColumn] as String,
        );
      }
    }

    return null;
  }

  /// Checked right after role resolution (`resolveDestinationRoute`, and
  /// again in the router's role-area guard for an already-open session) --
  /// Supabase Auth login itself can't be blocked by RLS (it happens before
  /// any Postgres query runs), so this is the actual enforcement point for
  /// "a revoked organisation's staff/an inactive official can't use the
  /// app": their auth login still technically succeeds, but this catches
  /// it immediately afterward and the caller signs them back out. Returns
  /// a human-readable reason if the account should be blocked, or `null`
  /// if it's fine. Citizens have no such gate -- `citizens.is_active`
  /// governs departmental service access, not login, by existing design.
  Future<String?> checkAccountActive(RoleLookupResult result) async {
    switch (result.role) {
      case UserRole.organisationUser:
        final row = await _client
            .from('organisation_users')
            .select('active, organisations(registration_status)')
            .eq('organisation_user_id', result.identityId)
            .maybeSingle();
        if (row == null) return null;
        if (row['active'] == false) {
          return 'Your account has been deactivated by your organisation\'s administrator.';
        }
        final status = row['organisations']?['registration_status'] as String?;
        if (status == 'revoked') {
          return 'Your organisation\'s access to UbuntuID has been revoked. Contact a UbuntuID administrator.';
        }
        return null;

      case UserRole.departmentOfficial:
        final row = await _client
            .from('department_officials')
            .select('active')
            .eq('official_id', result.identityId)
            .maybeSingle();
        if (row?['active'] == false) {
          return 'Your account has been deactivated by your department\'s administrator.';
        }
        return null;

      case UserRole.citizen:
      case UserRole.administrator:
        return null;
    }
  }

  /// If Home Affairs already created a `citizens` row for this person's
  /// email (before they ever had a login), this links the freshly
  /// self-registered auth account to that row -- server-side, via the
  /// `claim_citizen_account` RPC, which only ever touches a row with a
  /// matching email that isn't already linked to anything. Returns `true`
  /// if a row was claimed.
  Future<bool> claimCitizenAccount() async {
    final result = await _client.rpc('claim_citizen_account');
    return result == true;
  }
}
