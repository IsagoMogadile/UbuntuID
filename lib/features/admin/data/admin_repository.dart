import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../services/service_providers.dart';
import '../domain/appeal_item.dart';
import '../domain/admin_search_hit.dart';
import '../domain/admin_stats.dart';
import '../domain/audit_log_item.dart';
import '../domain/compliance_audit_item.dart';
import '../domain/department_list_item.dart';
import '../domain/department_official_detail.dart';
import '../domain/flagged_record_item.dart';
import '../domain/household_record_item.dart';
import '../domain/organisation_list_item.dart';
import '../domain/user_list_item.dart';

/// Real Supabase-backed administrator data source. Schema reference:
/// docs/SCREEN_DATABASE_MAP.md §5. A handful of columns referenced here
/// (`departments.contact_email`, `organisations.contact_email`, role
/// tables' `email`) are not directly confirmed in the schema map; each read
/// path below tries the richer query first and falls back to a safe subset
/// if Postgres reports the column doesn't exist (error code 42703), rather
/// than guessing and risking a broken screen. See
/// docs/KNOWN_LIMITATIONS.md.
class CreatedDepartmentOfficial {
  const CreatedDepartmentOfficial({
    required this.officialId,
    required this.email,
    required this.employeeReference,
  });

  final String officialId;
  final String email;
  final String employeeReference;
}

class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  static DateTime _date(dynamic v) => DateTime.tryParse(v as String? ?? '') ?? DateTime.now();

  Future<AdminStats> getStats() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final results = await Future.wait([
      _client.from('citizens').count(CountOption.exact),
      _client.from('department_officials').count(CountOption.exact),
      _client.from('organisations').count(CountOption.exact),
      // 'in_review' is not a valid overall_status value (confirmed live via
      // verification_status_check); 'processing' is the real in-flight state.
      _client.from('verification_requests').count(CountOption.exact).inFilter(
        'overall_status',
        ['pending', 'processing'],
      ),
      _client.from('flagged_records').count(CountOption.exact).eq('status', 'open'),
      _client.from('audit_logs').count(CountOption.exact).gte('occurred_at', thirtyDaysAgo),
    ]);

    return AdminStats(
      totalCitizens: results[0],
      departmentOfficials: results[1],
      organisations: results[2],
      pendingVerifications: results[3],
      flaggedRecords: results[4],
      recentAuditEvents: results[5],
    );
  }

  /// The signed-in administrator's own `full_name`, or `null` if the
  /// `ubuntuid_administrators` row has none.
  Future<String?> getCurrentAdminName() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AppException('You are not signed in.');
    final row = await _client
        .from('ubuntuid_administrators')
        .select('full_name')
        .eq('auth_user_id', userId)
        .maybeSingle();
    final name = (row?['full_name'] as String?)?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  Future<List<ComplianceAuditItem>> getComplianceAudits() async {
    final rows = await _client
        .from('compliance_audits')
        .select('audit_id, period_start, period_end, generated_at, summary, '
            'total_verification_requests, total_flagged_records, total_resolved_records, '
            'ubuntuid_administrators(full_name)')
        .order('generated_at', ascending: false);
    return [
      for (final row in rows)
        ComplianceAuditItem(
          auditId: row['audit_id'] as String,
          periodStart: _date(row['period_start']),
          periodEnd: _date(row['period_end']),
          generatedAt: _date(row['generated_at']),
          totalVerificationRequests: row['total_verification_requests'] as int? ?? 0,
          totalFlaggedRecords: row['total_flagged_records'] as int? ?? 0,
          totalResolvedRecords: row['total_resolved_records'] as int? ?? 0,
          summary: row['summary'] as String?,
          generatedByName: row['ubuntuid_administrators']?['full_name'] as String?,
        ),
    ];
  }

  /// `human_settlements_records` has no department official of its own
  /// (`docs/PROJECT_SCOPE.md` §5) -- an administrator is the only role that
  /// oversees this generic household data.
  Future<List<HouseholdRecordItem>> getHouseholdRecords() async {
    final rows = await _client
        .from('human_settlements_records')
        .select('record_id, record_type, recorded_at, record_data, '
            'citizens(first_name, last_name), properties(property_reference)')
        .order('recorded_at', ascending: false);
    return [
      for (final row in rows)
        HouseholdRecordItem(
          recordId: row['record_id'] as String,
          recordType: row['record_type'] as String? ?? 'RECORD',
          recordedAt: _date(row['recorded_at']),
          citizenName: '${row['citizens']?['first_name'] ?? ''} ${row['citizens']?['last_name'] ?? ''}'.trim(),
          propertyReference: row['properties']?['property_reference'] as String? ?? 'Unknown property',
          recordData: (row['record_data'] as Map<String, dynamic>?) ?? const {},
        ),
    ];
  }

  Future<List<UserListItem>> _fetchUsersFromTable({
    required String table,
    required String idColumn,
    required AdminUserRole role,
    required String genericLabel,
    required String nameColumns,
    required String Function(Map<String, dynamic> row) buildName,
    required String statusColumn,
    required bool Function(dynamic statusValue) isActive,
    // Live schema is not uniform: `citizens` uses `registered_at`, the
    // other three role tables use `created_at`. See docs/KNOWN_LIMITATIONS.md.
    String timestampColumn = 'created_at',
    // Only relevant for `department_officials` -- lets a department's
    // detail screen filter this role down to just its own officials.
    bool includeDepartmentId = false,
  }) async {
    final deptSuffix = includeDepartmentId ? ', department_id' : '';
    final fullColumns = '$idColumn, $nameColumns, $statusColumn, email, $timestampColumn$deptSuffix';
    final noEmailColumns = '$idColumn, $nameColumns, $statusColumn, $timestampColumn$deptSuffix';
    final minimalColumns = '$idColumn, $statusColumn, $timestampColumn$deptSuffix';

    List<Map<String, dynamic>> rows;
    var hasEmail = true;
    var hasName = true;
    try {
      rows = await _client.from(table).select(fullColumns);
    } on PostgrestException catch (e) {
      if (e.code != '42703') rethrow;
      hasEmail = false;
      try {
        rows = await _client.from(table).select(noEmailColumns);
      } on PostgrestException catch (e2) {
        if (e2.code != '42703') rethrow;
        hasName = false;
        rows = await _client.from(table).select(minimalColumns);
      }
    }

    return [
      for (final row in rows)
        UserListItem(
          userId: row[idColumn] as String,
          displayName: hasName ? buildName(row) : genericLabel,
          email: hasEmail ? (row['email'] as String? ?? 'Not on file') : 'Not on file',
          role: role,
          active: isActive(row[statusColumn]),
          createdAt: _date(row[timestampColumn]),
          departmentId: includeDepartmentId ? row['department_id'] as String? : null,
        ),
    ];
  }

  Future<List<UserListItem>> getUsers() async {
    final results = await Future.wait([
      _fetchUsersFromTable(
        table: 'citizens',
        idColumn: 'citizen_id',
        role: AdminUserRole.citizen,
        genericLabel: 'Citizen',
        nameColumns: 'first_name, last_name',
        buildName: (r) => '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim(),
        statusColumn: 'current_status',
        isActive: (v) => v == 'active',
        timestampColumn: 'registered_at',
      ),
      _fetchUsersFromTable(
        table: 'department_officials',
        idColumn: 'official_id',
        role: AdminUserRole.departmentOfficial,
        genericLabel: 'Department Official',
        nameColumns: 'full_name',
        buildName: (r) => r['full_name'] as String? ?? 'Department Official',
        statusColumn: 'active',
        isActive: (v) => v != false,
        includeDepartmentId: true,
      ),
      _fetchUsersFromTable(
        table: 'organisation_users',
        idColumn: 'organisation_user_id',
        role: AdminUserRole.organisationUser,
        genericLabel: 'Organisation User',
        nameColumns: 'full_name',
        buildName: (r) => r['full_name'] as String? ?? 'Organisation User',
        statusColumn: 'active',
        isActive: (v) => v != false,
      ),
      _fetchUsersFromTable(
        table: 'ubuntuid_administrators',
        idColumn: 'admin_id',
        role: AdminUserRole.administrator,
        genericLabel: 'Administrator',
        nameColumns: 'full_name',
        buildName: (r) => r['full_name'] as String? ?? 'Administrator',
        statusColumn: 'active',
        isActive: (v) => v != false,
      ),
    ]);

    final all = [for (final list in results) ...list];
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  /// Suspend/reactivate -- never deletes a row. Citizens use the
  /// `current_status` string column; the other three role tables use a
  /// boolean `active` column (see docs/SCREEN_DATABASE_MAP.md §5's own
  /// "active/current_status" phrasing).
  Future<void> setUserActive({
    required AdminUserRole role,
    required String userId,
    required bool active,
  }) {
    switch (role) {
      case AdminUserRole.citizen:
        return _client
            .from('citizens')
            .update({'current_status': active ? 'active' : 'suspended'}).eq('citizen_id', userId);
      case AdminUserRole.departmentOfficial:
        return _client
            .from('department_officials')
            .update({'active': active}).eq('official_id', userId);
      case AdminUserRole.organisationUser:
        return _client
            .from('organisation_users')
            .update({'active': active}).eq('organisation_user_id', userId);
      case AdminUserRole.administrator:
        return _client
            .from('ubuntuid_administrators')
            .update({'active': active}).eq('admin_id', userId);
    }
  }

  Future<List<OrganisationListItem>> getOrganisations() async {
    // `organisations` uses `registered_at`, not `created_at` -- see
    // docs/KNOWN_LIMITATIONS.md.
    const base = 'organisation_id, legal_name, organisation_type, access_tier, verified, registered_at, '
        'registration_status, decline_reason, revoked_at, revoke_reason, reinstated_at, reinstate_reason';
    var hasContactEmail = true;
    List<Map<String, dynamic>> rows;
    try {
      rows = await _client.from('organisations').select('$base, contact_email').order('legal_name');
    } on PostgrestException catch (e) {
      if (e.code != '42703') rethrow;
      hasContactEmail = false;
      rows = await _client.from('organisations').select(base).order('legal_name');
    }

    return [
      for (final row in rows)
        OrganisationListItem(
          organisationId: row['organisation_id'] as String,
          legalName: row['legal_name'] as String? ?? 'Organisation',
          organisationType: row['organisation_type'] as String? ?? 'Unknown',
          accessTier: row['access_tier'] as String? ?? 'standard',
          verified: row['verified'] as bool? ?? false,
          contactEmail: hasContactEmail ? (row['contact_email'] as String? ?? 'Not on file') : 'Not on file',
          registeredAt: _date(row['registered_at']),
          registrationStatus: row['registration_status'] as String? ?? (row['verified'] == true ? 'approved' : 'pending'),
          declineReason: row['decline_reason'] as String?,
          revokedAt: row['revoked_at'] == null ? null : DateTime.tryParse(row['revoked_at'] as String),
          revokeReason: row['revoke_reason'] as String?,
          reinstatedAt: row['reinstated_at'] == null ? null : DateTime.tryParse(row['reinstated_at'] as String),
          reinstateReason: row['reinstate_reason'] as String?,
        ),
    ];
  }

  Future<void> setOrganisationVerified(String organisationId, bool verified) {
    return _client.from('organisations').update({'verified': verified}).eq('organisation_id', organisationId);
  }

  /// `registration_status = 'revoked'` -- blocks the organisation's staff
  /// from data access (same `current_org_user_organisation_id()` choke
  /// point pending/declined already use) and, going forward, from logging
  /// in at all (see `RoleService.checkAccountActive`, checked right after
  /// login in `app_router.dart`). Reversible via [reinstateOrganisation].
  Future<void> revokeOrganisation({required String organisationId, required String reason}) {
    return _client.rpc('admin_revoke_organisation', params: {
      'p_organisation_id': organisationId,
      'p_reason': reason,
    });
  }

  Future<void> reinstateOrganisation({required String organisationId, required String reason}) {
    return _client.rpc('admin_reinstate_organisation', params: {
      'p_organisation_id': organisationId,
      'p_reason': reason,
    });
  }

  /// Approves or declines a pending (or previously declined) organisation
  /// application via the `admin_review_organisation` SECURITY DEFINER RPC --
  /// re-checks `is_admin()` server-side and records the decision in
  /// `organisation_verifications`.
  Future<void> reviewOrganisation({
    required String organisationId,
    required bool approve,
    String? notes,
  }) {
    return _client.rpc('admin_review_organisation', params: {
      'p_organisation_id': organisationId,
      'p_approve': approve,
      'p_notes': notes,
    });
  }

  Future<List<DepartmentListItem>> getDepartments() async {
    const base = 'department_id, department_name, category, active';
    var hasContactEmail = true;
    List<Map<String, dynamic>> rows;
    try {
      rows = await _client.from('departments').select('$base, contact_email').order('department_name');
    } on PostgrestException catch (e) {
      if (e.code != '42703') rethrow;
      hasContactEmail = false;
      rows = await _client.from('departments').select(base).order('department_name');
    }

    final countsByDepartment = <String, int>{};
    try {
      final officialRows = await _client.from('department_officials').select('department_id');
      for (final row in officialRows) {
        final id = row['department_id'] as String?;
        if (id != null) countsByDepartment[id] = (countsByDepartment[id] ?? 0) + 1;
      }
    } on PostgrestException {
      // Officials-per-department is a nice-to-have count; don't let a
      // failure here take down the whole departments screen.
    }

    return [
      for (final row in rows)
        DepartmentListItem(
          departmentId: row['department_id'] as String,
          departmentName: row['department_name'] as String? ?? 'Department',
          category: row['category'] as String? ?? 'General',
          active: row['active'] as bool? ?? true,
          officialsCount: countsByDepartment[row['department_id']] ?? 0,
          contactEmail: hasContactEmail ? (row['contact_email'] as String? ?? 'Not on file') : 'Not on file',
        ),
    ];
  }

  Future<void> setDepartmentActive(String departmentId, bool active) {
    return _client.from('departments').update({'active': active}).eq('department_id', departmentId);
  }

  /// Admin-only. Previously departments were seed data only (no in-app
  /// create flow -- see docs/FUTURE_WORK.md). `departments_write` RLS
  /// already grants `is_admin()` `ALL` on this table, so a plain client
  /// INSERT needs no new RPC. A newly created department has no
  /// `department_record_config.dart` entry (falls through to "No record
  /// types configured" on the citizen-records screen) and no dedicated
  /// `DepartmentCategory` (dashboard shows generic stats only) until one is
  /// added in code -- creating the row here is the department *existing*
  /// (so officials can be assigned to it, credential types can reference
  /// it), not a full department-specific workflow.
  Future<void> createDepartment({
    required String departmentCode,
    required String departmentName,
    required String category,
    String? contactEmail,
    String? contactPhone,
  }) {
    return _client.from('departments').insert({
      'department_code': departmentCode,
      'department_name': departmentName,
      'category': category,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'active': true,
    });
  }

  // ---------------------------------------------------------------------
  // Department official CRUD (admin-only). Create/delete go through
  // SECURITY DEFINER RPCs (`admin_create_department_official` /
  // `admin_delete_department_official`) since creating/removing a login
  // requires elevated privileges the Flutter client must never hold
  // directly -- both re-check `is_admin()` server-side, so a non-admin
  // calling them directly gets a clean rejection, not a silent no-op.
  // ---------------------------------------------------------------------

  Future<DepartmentOfficialDetail> getDepartmentOfficial(String officialId) async {
    final row = await _client
        .from('department_officials')
        .select('official_id, first_name, last_name, official_role, employee_reference, department_id, active, email')
        .eq('official_id', officialId)
        .single();
    return DepartmentOfficialDetail(
      officialId: row['official_id'] as String,
      firstName: row['first_name'] as String? ?? '',
      lastName: row['last_name'] as String? ?? '',
      officialRole: row['official_role'] as String? ?? '',
      departmentId: row['department_id'] as String,
      active: row['active'] as bool? ?? true,
      employeeReference: row['employee_reference'] as String?,
      email: row['email'] as String?,
    );
  }

  /// Login email and employee reference are auto-generated server-side
  /// (`name.surname@` + the department's domain, `DEPT_CODE-000123`) unless a
  /// non-empty override is passed. Returns the values the RPC actually
  /// assigned so the UI can show them to the admin.
  Future<CreatedDepartmentOfficial> createDepartmentOfficial({
    required String firstName,
    required String lastName,
    required String password,
    required String officialRole,
    required String departmentId,
    String? employeeReference,
    String? email,
  }) async {
    final result = await _client.rpc('admin_create_department_official', params: {
      'p_first_name': firstName,
      'p_last_name': lastName,
      'p_password': password,
      'p_official_role': officialRole,
      'p_department_id': departmentId,
      if (employeeReference != null && employeeReference.isNotEmpty) 'p_employee_reference': employeeReference,
      if (email != null && email.isNotEmpty) 'p_email': email,
    }) as Map<String, dynamic>;
    return CreatedDepartmentOfficial(
      officialId: result['official_id'] as String,
      email: result['email'] as String,
      employeeReference: result['employee_reference'] as String,
    );
  }

  Future<void> updateDepartmentOfficial({
    required String officialId,
    required String firstName,
    required String lastName,
    required String officialRole,
    required String departmentId,
    String? employeeReference,
  }) {
    return _client.from('department_officials').update({
      'first_name': firstName,
      'last_name': lastName,
      'official_role': officialRole,
      'department_id': departmentId,
      'employee_reference': employeeReference,
    }).eq('official_id', officialId);
  }

  Future<void> deleteDepartmentOfficial(String officialId) {
    return _client.rpc('admin_delete_department_official', params: {'p_official_id': officialId});
  }

  static const _searchLimitPerKind = 25;

  /// The admin header's universal search -- every actor an administrator
  /// oversees (citizens, department officials, organisation users,
  /// administrators, organisations, departments) by name, ID number,
  /// registration number/department code or email, all in one go.
  ///
  /// Each word typed must appear somewhere in the row, in any order ("Thabo
  /// Mokoena" and "mokoena thabo" both match). The longest word is matched
  /// server-side to keep each query small; the rest are checked here.
  /// Characters that would break a PostgREST `or=` filter are dropped.
  Future<List<AdminSearchHit>> searchEverything(String rawQuery) async {
    final words = rawQuery
        .replaceAll(RegExp(r'[,()*%\\."\x27:]'), ' ')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];
    final lead = words.reduce((a, b) => b.length > a.length ? b : a);
    bool matchesAll(List<Object?> fields) {
      final haystack = fields.whereType<String>().join(' ').toLowerCase();
      return words.every(haystack.contains);
    }

    Future<List<AdminSearchHit>> staff({
      required String table,
      required String idColumn,
      required AdminSearchKind kind,
    }) async {
      final rows = await _client
          .from(table)
          .select('$idColumn, full_name, id_number, email, active')
          .or('full_name.ilike.*$lead*,id_number.ilike.$lead*,email.ilike.*$lead*')
          .order('full_name')
          .limit(_searchLimitPerKind);
      return [
        for (final row in rows)
          if (matchesAll([row['full_name'], row['id_number'], row['email']]))
            AdminSearchHit(
              kind: kind,
              id: row[idColumn] as String,
              title: row['full_name'] as String? ?? kind.label,
              subtitle: [row['id_number'], row['email']].whereType<String>().join(' · '),
              status: row['active'] == false ? 'inactive' : 'active',
            ),
      ];
    }

    Future<List<AdminSearchHit>> citizens() async {
      final rows = await _client
          .from('citizens')
          .select('citizen_id, first_name, last_name, id_number, email, current_status')
          .or('first_name.ilike.*$lead*,last_name.ilike.*$lead*,id_number.ilike.$lead*,email.ilike.*$lead*')
          .order('last_name')
          .limit(_searchLimitPerKind);
      return [
        for (final row in rows)
          if (matchesAll([row['first_name'], row['last_name'], row['id_number'], row['email']]))
            AdminSearchHit(
              kind: AdminSearchKind.citizen,
              id: row['citizen_id'] as String,
              title: '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim(),
              subtitle: row['id_number'] as String? ?? '',
              status: row['current_status'] as String? ?? 'unknown',
            ),
      ];
    }

    Future<List<AdminSearchHit>> organisations() async {
      final rows = await _client
          .from('organisations')
          .select('organisation_id, legal_name, registration_number, organisation_type, registration_status')
          .or('legal_name.ilike.*$lead*,registration_number.ilike.*$lead*')
          .order('legal_name')
          .limit(_searchLimitPerKind);
      return [
        for (final row in rows)
          if (matchesAll([row['legal_name'], row['registration_number']]))
            AdminSearchHit(
              kind: AdminSearchKind.organisation,
              id: row['organisation_id'] as String,
              title: row['legal_name'] as String? ?? 'Organisation',
              subtitle: [row['registration_number'], row['organisation_type']].whereType<String>().join(' · '),
              status: row['registration_status'] as String? ?? 'pending',
            ),
      ];
    }

    Future<List<AdminSearchHit>> departments() async {
      final rows = await _client
          .from('departments')
          .select('department_id, department_name, department_code, category, active')
          .or('department_name.ilike.*$lead*,department_code.ilike.*$lead*')
          .order('department_name')
          .limit(_searchLimitPerKind);
      return [
        for (final row in rows)
          if (matchesAll([row['department_name'], row['department_code']]))
            AdminSearchHit(
              kind: AdminSearchKind.department,
              id: row['department_id'] as String,
              title: row['department_name'] as String? ?? 'Department',
              subtitle: [row['department_code'], row['category']].whereType<String>().join(' · '),
              status: row['active'] == false ? 'inactive' : 'active',
            ),
      ];
    }

    final results = await Future.wait([
      citizens(),
      staff(table: 'department_officials', idColumn: 'official_id', kind: AdminSearchKind.departmentOfficial),
      staff(table: 'organisation_users', idColumn: 'organisation_user_id', kind: AdminSearchKind.organisationUser),
      staff(table: 'ubuntuid_administrators', idColumn: 'admin_id', kind: AdminSearchKind.administrator),
      organisations(),
      departments(),
    ]);
    return [for (final list in results) ...list];
  }

  /// (actor_type, actor_id) -> resolved name, so a given official/admin/
  /// citizen/organisation user is only ever looked up once per session
  /// rather than re-queried on every stream emission.
  final Map<String, String> _actorNameCache = {};

  static const _actorTable = {
    'department_official': ('department_officials', 'official_id', 'full_name'),
    'administrator': ('ubuntuid_administrators', 'admin_id', 'full_name'),
    'organisation_user': ('organisation_users', 'organisation_user_id', 'full_name'),
  };

  /// Resolves the responsible official/administrator/organisation user's
  /// name for every row in this emission -- `actor_id` is polymorphic (see
  /// `AuditLogItem`), so it can't be embedded directly in the `.stream()`
  /// query the way a normal foreign-key join could (realtime streams don't
  /// support PostgREST embeds). Citizens are named inline
  /// (`first_name`/`last_name`, not `full_name`) via a second pass.
  Future<void> _resolveActorNames(List<Map<String, dynamic>> rows) async {
    final idsByActorType = <String, Set<String>>{};
    for (final row in rows) {
      final actorId = row['actor_id'] as String?;
      final actorType = row['actor_type'] as String?;
      if (actorId != null && actorType != null && !_actorNameCache.containsKey('$actorType:$actorId')) {
        idsByActorType.putIfAbsent(actorType, () => {}).add(actorId);
      }
      // target_citizen_id shares the same 'citizen:<id>' cache key as an
      // actor_type='citizen' actor -- a citizen row resolves the same way
      // either as who did something or who something was done to.
      final targetCitizenId = row['target_citizen_id'] as String?;
      if (targetCitizenId != null && !_actorNameCache.containsKey('citizen:$targetCitizenId')) {
        idsByActorType.putIfAbsent('citizen', () => {}).add(targetCitizenId);
      }
    }
    if (idsByActorType.isEmpty) return;

    for (final entry in idsByActorType.entries) {
      final config = _actorTable[entry.key];
      if (config != null) {
        final (table, idColumn, nameColumn) = config;
        final rows2 = await _client.from(table).select('$idColumn, $nameColumn').inFilter(idColumn, entry.value.toList());
        for (final r in rows2) {
          _actorNameCache['${entry.key}:${r[idColumn]}'] = r[nameColumn] as String? ?? 'Unknown';
        }
      } else if (entry.key == 'citizen') {
        final rows2 = await _client
            .from('citizens')
            .select('citizen_id, first_name, last_name')
            .inFilter('citizen_id', entry.value.toList());
        for (final r in rows2) {
          _actorNameCache['citizen:${r['citizen_id']}'] =
              '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
        }
      }
    }
  }

  /// Live-updating: `audit_logs` is in the `supabase_realtime` publication,
  /// so this pushes new rows as they're written (department changes,
  /// verification activity, etc.) instead of requiring a manual refresh.
  /// RLS (admin-only SELECT) still governs what a given subscriber receives.
  /// Each emission is also resolved to the responsible official/
  /// administrator/citizen/organisation user's name (`_resolveActorNames`)
  /// -- spec: "for audit on the admin, also state which official is
  /// responsible".
  Stream<List<AuditLogItem>> streamAuditLogs() {
    return _client
        .from('audit_logs')
        .stream(primaryKey: ['log_id'])
        .order('occurred_at', ascending: false)
        .limit(200)
        .asyncMap((rows) async {
          await _resolveActorNames(rows);
          return [
            for (final row in rows)
              AuditLogItem(
                logId: row['log_id'] as String,
                actorType: row['actor_type'] as String? ?? 'unknown',
                actorId: row['actor_id'] as String?,
                actorName: row['actor_id'] == null
                    ? null
                    : _actorNameCache['${row['actor_type']}:${row['actor_id']}'],
                action: row['action'] as String? ?? '',
                relatedTable: row['related_table'] as String? ?? '',
                occurredAt: _date(row['occurred_at']),
                ipAddress: row['ip_address'] as String?,
                targetCitizenId: row['target_citizen_id'] as String?,
                targetCitizenName: row['target_citizen_id'] == null
                    ? null
                    : _actorNameCache['citizen:${row['target_citizen_id']}'],
                metadata: row['metadata'] as Map<String, dynamic>?,
              ),
          ];
        });
  }

  Future<List<AppealItem>> getAppeals() async {
    final rows = await _client
        .from('appeals')
        .select('appeal_id, citizen_id, related_table, appeal_reason, status, submitted_at, '
            'decision, decision_date, decision_notes, '
            'citizens(first_name, last_name), departments(department_name), '
            'department_officials(full_name)')
        .order('submitted_at', ascending: false);
    return [
      for (final row in rows)
        AppealItem(
          appealId: row['appeal_id'] as String,
          citizenId: row['citizen_id'] as String,
          citizenDisplayName: _citizenName(row['citizens'] as Map<String, dynamic>?),
          departmentName: (row['departments']?['department_name'] as String?) ?? 'Unknown department',
          relatedTable: row['related_table'] as String? ?? '',
          appealReason: row['appeal_reason'] as String? ?? '',
          status: row['status'] as String? ?? 'submitted',
          submittedAt: _date(row['submitted_at']),
          lodgedByName: row['department_officials']?['full_name'] as String?,
          decision: row['decision'] as String?,
          decisionDate: row['decision_date'] == null ? null : DateTime.tryParse(row['decision_date'] as String),
          decisionNotes: row['decision_notes'] as String?,
        ),
    ];
  }

  Future<void> startAppealReview(String appealId) {
    return _client.rpc('admin_start_appeal_review', params: {'p_appeal_id': appealId});
  }

  Future<void> decideAppeal({
    required String appealId,
    required bool uphold,
    required String decisionNotes,
  }) {
    return _client.rpc('admin_decide_appeal', params: {
      'p_appeal_id': appealId,
      'p_decision': uphold ? 'upheld' : 'rejected',
      'p_decision_notes': decisionNotes,
    });
  }

  Future<List<FlaggedRecordItem>> getFlaggedRecords() async {
    final rows = await _client
        .from('flagged_records')
        .select('flag_id, citizen_id, reason, status, raised_at, resolution_notes, citizens(first_name, last_name)')
        .order('raised_at', ascending: false);

    return [
      for (final row in rows)
        FlaggedRecordItem(
          flagId: row['flag_id'] as String,
          citizenId: row['citizen_id'] as String?,
          citizenDisplayName: _citizenName(row['citizens'] as Map<String, dynamic>?),
          reason: row['reason'] as String? ?? '',
          status: row['status'] as String? ?? 'open',
          raisedAt: _date(row['raised_at']),
          resolutionNotes: row['resolution_notes'] as String?,
        ),
    ];
  }

  static String _citizenName(Map<String, dynamic>? citizen) {
    final name = '${citizen?['first_name'] ?? ''} ${citizen?['last_name'] ?? ''}'.trim();
    return name.isEmpty ? 'Unknown citizen' : name;
  }

  Future<void> resolveFlaggedRecord(String flagId, {required String resolutionNotes}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AppException('You are not signed in.');
    final adminRow =
        await _client.from('ubuntuid_administrators').select('admin_id').eq('auth_user_id', userId).maybeSingle();

    await _client.from('flagged_records').update({
      'status': 'resolved',
      'resolution_notes': resolutionNotes,
      'resolved_at': DateTime.now().toIso8601String(),
      if (adminRow != null) 'assigned_admin_id': adminRow['admin_id'],
    }).eq('flag_id', flagId);
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  ref.watch(authStateChangesProvider);
  return AdminRepository(ref.watch(supabaseClientProvider));
});

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) {
  return ref.watch(adminRepositoryProvider).getStats();
});

final currentAdminNameProvider = FutureProvider.autoDispose<String?>((ref) {
  return ref.watch(adminRepositoryProvider).getCurrentAdminName();
});

final adminUsersProvider =FutureProvider.autoDispose<List<UserListItem>>((ref) {
  return ref.watch(adminRepositoryProvider).getUsers();
});

final adminOrganisationsProvider = FutureProvider.autoDispose<List<OrganisationListItem>>((ref) {
  return ref.watch(adminRepositoryProvider).getOrganisations();
});

final adminDepartmentsProvider = FutureProvider.autoDispose<List<DepartmentListItem>>((ref) {
  return ref.watch(adminRepositoryProvider).getDepartments();
});

final adminAuditLogsProvider = StreamProvider.autoDispose<List<AuditLogItem>>((ref) {
  return ref.watch(adminRepositoryProvider).streamAuditLogs();
});

final adminFlaggedRecordsProvider = FutureProvider.autoDispose<List<FlaggedRecordItem>>((ref) {
  return ref.watch(adminRepositoryProvider).getFlaggedRecords();
});

final adminAppealsProvider = FutureProvider.autoDispose<List<AppealItem>>((ref) {
  return ref.watch(adminRepositoryProvider).getAppeals();
});

final adminComplianceAuditsProvider = FutureProvider.autoDispose<List<ComplianceAuditItem>>((ref) {
  return ref.watch(adminRepositoryProvider).getComplianceAudits();
});

final adminHouseholdRecordsProvider = FutureProvider.autoDispose<List<HouseholdRecordItem>>((ref) {
  return ref.watch(adminRepositoryProvider).getHouseholdRecords();
});

final departmentOfficialDetailProvider =
    FutureProvider.autoDispose.family<DepartmentOfficialDetail, String>((ref, officialId) {
  return ref.watch(adminRepositoryProvider).getDepartmentOfficial(officialId);
});
