import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/user_role.dart';
import '../../../services/role_service.dart';
import '../../../services/service_providers.dart';
import '../domain/verification_request_summary.dart';

/// Real Supabase-backed verification data source, shared by the department
/// official, organisation and administrator roles -- they all read/act on
/// the same `verification_requests` / `verification_results` tables, scoped
/// differently per role. See docs/SCREEN_DATABASE_MAP.md §6 and
/// docs/KNOWN_LIMITATIONS.md.
class VerificationRepository {
  VerificationRepository(this._client, this._roleService);

  final SupabaseClient _client;
  final RoleService _roleService;

  static const _requestSelect = 'request_id, overall_status, requested_at, responded_at, '
      'processing_started_at, org_viewed_at, organisation_id, citizen_id, '
      'citizens(first_name, last_name), organisations(legal_name)';

  Future<RoleLookupResult?> _currentRole() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return _roleService.detectRole(userId);
  }

  VerificationRequestSummary _mapRequest(Map<String, dynamic> row) {
    final citizen = row['citizens'] as Map<String, dynamic>?;
    final organisation = row['organisations'] as Map<String, dynamic>?;
    final citizenName =
        '${(citizen?['first_name'] as String? ?? '').trim()} ${(citizen?['last_name'] as String? ?? '').trim()}'
            .trim();
    return VerificationRequestSummary(
      requestId: row['request_id'] as String,
      organisationId: row['organisation_id'] as String?,
      citizenId: row['citizen_id'] as String?,
      citizenDisplayName: citizenName.isEmpty ? 'Unknown citizen' : citizenName,
      organisationName: (organisation?['legal_name'] as String?) ?? 'Unknown organisation',
      overallStatus: row['overall_status'] as String? ?? 'pending',
      requestedAt: DateTime.tryParse(row['requested_at'] as String? ?? '') ?? DateTime.now(),
      respondedAt:
          row['responded_at'] == null ? null : DateTime.tryParse(row['responded_at'] as String),
      processingStartedAt:
          row['processing_started_at'] == null ? null : DateTime.tryParse(row['processing_started_at'] as String),
      orgViewedAt: row['org_viewed_at'] == null ? null : DateTime.tryParse(row['org_viewed_at'] as String),
    );
  }

  Future<List<String>> _departmentCredentialTypeIds(String departmentId) async {
    final rows = await _client
        .from('credential_types')
        .select('credential_type_id')
        .eq('issuing_department_id', departmentId);
    return [for (final row in rows) row['credential_type_id'] as String];
  }

  Future<List<String>> _requestIdsForCredentialTypes(List<String> credentialTypeIds) async {
    if (credentialTypeIds.isEmpty) return [];
    final rows = await _client
        .from('verification_results')
        .select('request_id')
        .inFilter('credential_type_id', credentialTypeIds);
    return {for (final row in rows) row['request_id'] as String}.toList();
  }

  /// The signed-in official's/organisation user's own scoping id, or null
  /// for an administrator (who is unscoped) or a role with no verification
  /// visibility (citizen).
  Future<UserRole?> currentRole() async => (await _currentRole())?.role;

  Future<List<VerificationRequestSummary>> getRequests() async {
    final role = await _currentRole();
    if (role == null) return [];

    switch (role.role) {
      case UserRole.administrator:
        final rows = await _client
            .from('verification_requests')
            .select(_requestSelect)
            .order('requested_at', ascending: false)
            .limit(200);
        return [for (final row in rows) _mapRequest(row)];

      case UserRole.organisationUser:
        // organisation_users.organisation_id confirmed live.
        final orgUserRow = await _client
            .from('organisation_users')
            .select('organisation_id')
            .eq('organisation_user_id', role.identityId)
            .maybeSingle();
        final organisationId = orgUserRow?['organisation_id'] as String?;
        if (organisationId == null) return [];
        final rows = await _client
            .from('verification_requests')
            .select(_requestSelect)
            .eq('organisation_id', organisationId)
            .order('requested_at', ascending: false);
        return [for (final row in rows) _mapRequest(row)];

      case UserRole.departmentOfficial:
        // department_officials.department_id confirmed live.
        final officialRow = await _client
            .from('department_officials')
            .select('department_id')
            .eq('official_id', role.identityId)
            .maybeSingle();
        final departmentId = officialRow?['department_id'] as String?;
        if (departmentId == null) return [];
        final credentialTypeIds = await _departmentCredentialTypeIds(departmentId);
        final requestIds = await _requestIdsForCredentialTypes(credentialTypeIds);
        if (requestIds.isEmpty) return [];
        final rows = await _client
            .from('verification_requests')
            .select(_requestSelect)
            .inFilter('request_id', requestIds)
            .order('requested_at', ascending: false);
        return [for (final row in rows) _mapRequest(row)];

      case UserRole.citizen:
        // role.identityId is already citizen_id here -- RoleService resolves
        // a citizen's identityId from `citizens.citizen_id` directly (see
        // lib/services/role_service.dart), unlike the org/department cases
        // above which need an extra lookup to translate a user-table id into
        // the id their own requests are actually scoped by.
        final rows = await _client
            .from('verification_requests')
            .select(_requestSelect)
            .eq('citizen_id', role.identityId)
            .order('requested_at', ascending: false);
        return [for (final row in rows) _mapRequest(row)];
    }
  }

  Future<VerificationRequestSummary> getRequest(String requestId) async {
    final row =
        await _client.from('verification_requests').select(_requestSelect).eq('request_id', requestId).single();
    return _mapRequest(row);
  }

  Future<List<VerificationResultLine>> getResultLines(String requestId) async {
    final rows = await _client
        .from('verification_results')
        .select('claimed_value, verified_value, match_status, credential_types(display_name)')
        .eq('request_id', requestId);
    return [
      for (final row in rows)
        VerificationResultLine(
          credentialTypeName: (row['credential_types']?['display_name'] as String?) ?? 'Credential',
          claimedValue: _stringifyJson(row['claimed_value']),
          verifiedValue: _stringifyJson(row['verified_value']),
          matchStatus: row['match_status'] as String? ?? 'pending',
        ),
    ];
  }

  static String _stringifyJson(dynamic value) {
    if (value == null) return 'Not provided';
    return value.toString();
  }

  /// The signed-in organisation user's own `organisation_id`, or null for
  /// any other role -- used to decide whether *this* user is the one
  /// allowed to start/complete/acknowledge a given request (the RPCs below
  /// re-check this server-side too; this is just for the UI to know
  /// whether to show the button at all).
  Future<String?> currentOrganisationId() async {
    final role = await _currentRole();
    if (role == null || role.role != UserRole.organisationUser) return null;
    final row = await _client
        .from('organisation_users')
        .select('organisation_id')
        .eq('organisation_user_id', role.identityId)
        .maybeSingle();
    return row?['organisation_id'] as String?;
  }

  /// `overall_status` is constrained live to `pending, processing,
  /// completed, partially_verified, failed, rejected, cancelled`
  /// (confirmed via `verification_status_check`). Nobody can set these by
  /// hand any more -- `start_verification`/`complete_verification`
  /// (docs/database/automated_verification_and_org_revocation.sql) are the
  /// only writers left; RLS was tightened to remove every direct client
  /// update path, so a department official or administrator can no longer
  /// "decide" a request themselves.
  Future<void> startVerification(String requestId) {
    return _client.rpc('start_verification', params: {'p_request_id': requestId});
  }

  /// Called after the client-side "processing" wait -- does the real
  /// claimed-vs-verified comparison and sets the terminal status. Returns
  /// the resulting `overall_status`.
  Future<String> completeVerification(String requestId) async {
    final result = await _client.rpc('complete_verification', params: {'p_request_id': requestId});
    return (result as Map<String, dynamic>)['overall_status'] as String? ?? 'failed';
  }

  /// Marks a completed request as seen by the organisation -- after this,
  /// re-opening the request only shows the summary status, not the
  /// per-credential claimed/verified detail (see
  /// `VerificationRequestDetailScreen`). A fresh look requires a new
  /// verification request.
  Future<void> acknowledgeResult(String requestId) {
    return _client.rpc('acknowledge_verification_result', params: {'p_request_id': requestId});
  }
}

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  ref.watch(authStateChangesProvider);
  return VerificationRepository(ref.watch(supabaseClientProvider), ref.watch(roleServiceProvider));
});

final verificationRequestsProvider = FutureProvider.autoDispose<List<VerificationRequestSummary>>((ref) {
  return ref.watch(verificationRepositoryProvider).getRequests();
});

final verificationRequestDetailProvider =
    FutureProvider.autoDispose.family<VerificationRequestSummary, String>((ref, requestId) {
  return ref.watch(verificationRepositoryProvider).getRequest(requestId);
});

final verificationResultLinesProvider =
    FutureProvider.autoDispose.family<List<VerificationResultLine>, String>((ref, requestId) {
  return ref.watch(verificationRepositoryProvider).getResultLines(requestId);
});

/// The signed-in organisation user's own `organisation_id`, or null for any
/// other role -- a request only shows Start/processing/Done controls to
/// the organisation that owns it (department officials/admins/citizens
/// only ever get a read-only view now; nobody "decides" any more).
final currentOrganisationIdProvider = FutureProvider.autoDispose<String?>((ref) {
  return ref.watch(verificationRepositoryProvider).currentOrganisationId();
});
