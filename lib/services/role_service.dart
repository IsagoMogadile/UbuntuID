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
