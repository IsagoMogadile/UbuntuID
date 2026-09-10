import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../services/service_providers.dart';
import '../../citizen/domain/credential_item.dart';
import '../../shared/data/qualification_lookup.dart';
import '../domain/organisation_colleague_item.dart';
import '../domain/organisation_dashboard_stats.dart';

/// Real Supabase-backed organisation-user data source. Schema reference:
/// docs/SCREEN_DATABASE_MAP.md §4. `organisation_users.organisation_id` is
/// confirmed live -- see docs/KNOWN_LIMITATIONS.md.
class OrganisationRepository {
  OrganisationRepository(this._client);

  final SupabaseClient _client;
  Future<Map<String, dynamic>>? _orgUserRowFuture;

  Future<Map<String, dynamic>> _orgUserRow() {
    return _orgUserRowFuture ??= () async {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw const AppException('You are not signed in.');
      final row = await _client
          .from('organisation_users')
          .select('organisation_user_id, full_name, user_role, organisation_id, '
              'organisations(organisation_id, legal_name, access_tier, verified, registration_status, decline_reason)')
          .eq('auth_user_id', userId)
          .maybeSingle();
      if (row == null) {
        throw const AppException('No organisation user record is linked to this account.');
      }
      return row;
    }();
  }

  Future<OrganisationApplicationStatus> getApplicationStatus() async {
    final row = await _orgUserRow();
    final organisation = row['organisations'] as Map<String, dynamic>?;
    return OrganisationApplicationStatus(
      organisationId: organisation?['organisation_id'] as String? ?? '',
      legalName: organisation?['legal_name'] as String? ?? 'Organisation',
      registrationStatus: organisation?['registration_status'] as String? ?? 'pending',
      declineReason: organisation?['decline_reason'] as String?,
      isHead: row['user_role'] == 'manager',
    );
  }

  /// Full editable detail for the resubmit-after-decline flow -- only the
  /// organisation's own head user can reach this (RLS scopes
  /// `organisations`/`organisation_credential_scopes` reads the same way).
  Future<Map<String, dynamic>> getOrganisationForResubmit(String organisationId) async {
    final org = await _client
        .from('organisations')
        .select('legal_name, registration_number, organisation_type, contact_email, contact_phone')
        .eq('organisation_id', organisationId)
        .single();
    final scopeRows = await _client
        .from('organisation_credential_scopes')
        .select('credential_types(type_code)')
        .eq('organisation_id', organisationId);
    org['selected_type_codes'] = [
      for (final r in scopeRows)
        if (r['credential_types']?['type_code'] != null) r['credential_types']['type_code'] as String,
    ];
    return org;
  }

  /// Registers a brand-new organisation application via the
  /// `register_organisation` SECURITY DEFINER RPC -- runs as one atomic
  /// operation server-side (org row + head user row + credential scope),
  /// requires an existing auth session (the caller must have already called
  /// `AuthService.signUp`), and leaves the organisation in `pending` status
  /// until an administrator reviews it.
  Future<void> registerOrganisation({
    required String legalName,
    required String registrationNumber,
    required String organisationType,
    required String contactEmail,
    required String contactPhone,
    required List<String> credentialTypeCodes,
    required String headFirstName,
    required String headLastName,
    required String headGender,
    required String headIdNumber,
  }) async {
    await _client.rpc('register_organisation', params: {
      'p_legal_name': legalName,
      'p_registration_number': registrationNumber,
      'p_organisation_type': organisationType,
      'p_contact_email': contactEmail,
      'p_contact_phone': contactPhone,
      'p_credential_type_codes': credentialTypeCodes,
      'p_head_first_name': headFirstName,
      'p_head_last_name': headLastName,
      'p_head_gender': headGender,
      'p_head_id_number': headIdNumber,
    });
  }

  /// Resubmits a declined application with updated details/scope -- only
  /// callable by that organisation's own head user (enforced server-side).
  Future<void> resubmitOrganisation({
    required String organisationId,
    required String legalName,
    required String registrationNumber,
    required String organisationType,
    required String contactEmail,
    required String contactPhone,
    required List<String> credentialTypeCodes,
  }) async {
    await _client.rpc('resubmit_organisation', params: {
      'p_organisation_id': organisationId,
      'p_legal_name': legalName,
      'p_registration_number': registrationNumber,
      'p_organisation_type': organisationType,
      'p_contact_email': contactEmail,
      'p_contact_phone': contactPhone,
      'p_credential_type_codes': credentialTypeCodes,
    });
    _orgUserRowFuture = null;
  }

  Future<String> getMyRole() async {
    final row = await _orgUserRow();
    return row['user_role'] as String? ?? 'member';
  }

  /// Fellow users in the caller's own organisation -- an Organisational
  /// Head or Admin additionally gets add/toggle-active actions in the UI,
  /// via the `org_admin_*` RPCs (self-service that previously only a
  /// System Administrator could do, and which fixes the earlier
  /// Head/`is_org_admin()` mismatch by not depending on that helper).
  Future<List<OrganisationColleagueItem>> getColleagues() async {
    final row = await _orgUserRow();
    final organisationId = (row['organisations'] as Map<String, dynamic>?)?['organisation_id'] as String?;
    if (organisationId == null) return [];

    final rows = await _client
        .from('organisation_users')
        .select('organisation_user_id, full_name, user_role, active')
        .eq('organisation_id', organisationId)
        .order('full_name');
    return [
      for (final r in rows)
        OrganisationColleagueItem(
          organisationUserId: r['organisation_user_id'] as String,
          fullName: r['full_name'] as String? ?? '',
          userRole: r['user_role'] as String? ?? 'member',
          active: r['active'] as bool? ?? true,
        ),
    ];
  }

  Future<Map<String, dynamic>> createStaffMember({
    required String firstName,
    required String lastName,
    required String password,
    String? email,
  }) async {
    final result = await _client.rpc('org_admin_create_staff', params: {
      'p_first_name': firstName,
      'p_last_name': lastName,
      'p_password': password,
      if (email != null && email.isNotEmpty) 'p_email': email,
    }) as Map<String, dynamic>;
    return result;
  }

  Future<void> setUserActive(String organisationUserId, bool active) {
    return _client.rpc('org_admin_set_user_active', params: {
      'p_organisation_user_id': organisationUserId,
      'p_active': active,
    });
  }

  /// The credential types *this* organisation was actually approved to
  /// verify -- shown on its own Profile screen so staff know their scope
  /// without guessing (spec suggestion #6).
  Future<List<CredentialTypeOption>> getMyCredentialScope() async {
    final row = await _orgUserRow();
    final organisationId = (row['organisations'] as Map<String, dynamic>?)?['organisation_id'] as String?;
    if (organisationId == null) return [];

    final rows = await _client
        .from('organisation_credential_scopes')
        .select('credential_types(credential_type_id, type_code, display_name, departments(department_name))')
        .eq('organisation_id', organisationId);
    return [
      for (final row in rows)
        if (row['credential_types'] != null)
          CredentialTypeOption(
            credentialTypeId: row['credential_types']['credential_type_id'] as String,
            typeCode: row['credential_types']['type_code'] as String,
            displayName: row['credential_types']['display_name'] as String? ?? 'Credential',
            issuingDepartment:
                (row['credential_types']['departments']?['department_name'] as String?) ?? 'Unknown department',
          ),
    ];
  }

  Future<List<CredentialTypeOption>> getAllCredentialTypes() async {
    final rows = await _client
        .from('credential_types')
        .select('credential_type_id, type_code, display_name, departments(department_name)')
        .eq('active', true)
        .order('display_name');
    return [
      for (final row in rows)
        CredentialTypeOption(
          credentialTypeId: row['credential_type_id'] as String,
          typeCode: row['type_code'] as String,
          displayName: row['display_name'] as String? ?? 'Credential',
          issuingDepartment: (row['departments']?['department_name'] as String?) ?? 'Unknown department',
        ),
    ];
  }

  /// Every citizen the organisation looks up must be resolved through this
  /// one search path -- there is no bulk/listing access to `citizens` for
  /// organisations (spec: "they dont see everyone"), which is why, unlike
  /// `DepartmentRepository.searchCitizens`/`AdminRepository.searchCitizens`,
  /// this deliberately keeps ID number mandatory and never offers a "view
  /// all" browse -- an organisation can only ever resolve a specific citizen
  /// it already has the ID number for, not enumerate the citizen table by
  /// name. Name matching is relaxed from "both first AND last, exact" to
  /// "at least one of first/last name, partial" -- still requires the exact
  /// ID number, just more forgiving of a typo'd or partially-known name.
  /// Returns a list (in practice 0 or 1 row, since `id_number` is unique)
  /// rather than a single guess, for the same result-list UI every other
  /// search screen now uses.
  Future<List<OrganisationCitizenSearchResult>> searchCitizens({
    required String idNumber,
    String? firstName,
    String? lastName,
  }) async {
    var query = _client
        .from('citizens')
        .select('citizen_id, first_name, last_name, id_number, current_status')
        .eq('id_number', idNumber.trim());
    if (firstName != null && firstName.trim().isNotEmpty) {
      query = query.ilike('first_name', '%${firstName.trim()}%');
    }
    if (lastName != null && lastName.trim().isNotEmpty) {
      query = query.ilike('last_name', '%${lastName.trim()}%');
    }
    final rows = await query;
    return [
      for (final row in rows)
        OrganisationCitizenSearchResult(
          citizenId: row['citizen_id'] as String,
          fullName: '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim(),
          idNumber: row['id_number'] as String? ?? idNumber,
          currentStatus: row['current_status'] as String? ?? 'unknown',
        ),
    ];
  }

  /// Same `credentials -> credential_types -> departments` join
  /// `CitizenRepository.getCredentials` uses, narrowed to only the
  /// credential types this organisation was approved to verify
  /// (`organisation_credential_scopes`, chosen at registration) -- a bank
  /// scoped to Passport/Licence/Tax never sees a citizen's criminal record
  /// or qualifications, even though the underlying `credentials` row exists.
  Future<List<VerifiableCredential>> getCitizenCredentialsForVerification(String citizenId) async {
    final orgRow = await _orgUserRow();
    final organisationId = (orgRow['organisations'] as Map<String, dynamic>?)?['organisation_id'] as String?;
    if (organisationId == null) return [];

    final scopeRows =
        await _client.from('organisation_credential_scopes').select('credential_type_id').eq('organisation_id', organisationId);
    final allowedTypeIds = {for (final r in scopeRows) r['credential_type_id'] as String};
    if (allowedTypeIds.isEmpty) return [];

    final rows = await _client
        .from('credentials')
        .select('credential_id, status, expiry_date, credential_type_id, '
            'credential_types(credential_type_id, type_code, display_name, departments(department_name)), '
            'citizens(id_number)')
        .eq('citizen_id', citizenId)
        .inFilter('credential_type_id', allowedTypeIds.toList())
        .order('issued_date', ascending: false);

    final idNumber = rows.isEmpty ? null : rows.first['citizens']?['id_number'] as String?;

    final items = <VerifiableCredential>[];
    for (final row in rows) {
      final typeCode = row['credential_types']?['type_code'] as String?;
      items.add(VerifiableCredential(
        credentialTypeId: row['credential_type_id'] as String,
        typeCode: typeCode ?? '',
        typeName: (row['credential_types']?['display_name'] as String?) ?? 'Credential',
        issuingDepartment:
            (row['credential_types']?['departments']?['department_name'] as String?) ?? 'Unknown department',
        status: _effectiveCredentialStatus(row['status'] as String?, _parseNullableDate(row['expiry_date'])),
        qualification: idNumber == null
            ? null
            : await fetchQualificationDetail(_client, typeCode: typeCode, nationalIdNumber: idNumber),
      ));
    }
    return items;
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  /// Mirrors `CitizenRepository._effectiveCredentialStatus` -- the `status`
  /// column is never flipped to `expired` as time passes (no scheduled
  /// job for it), so an organisation verifying a citizen must not trust it
  /// blindly once `expiry_date` has passed.
  static String _effectiveCredentialStatus(String? status, DateTime? expiryDate) {
    final raw = status ?? 'pending';
    if (raw == 'active' && expiryDate != null && expiryDate.isBefore(DateTime.now())) {
      return 'expired';
    }
    return raw;
  }

  /// Raises a verification request: one `consent_grants` row (recording
  /// that the organisation obtained the citizen's consent to check exactly
  /// these credential types -- required, `verification_requests.consent_id`
  /// is `NOT NULL` live, confirmed via a real end-to-end test against
  /// PostgREST, not assumed), then one `verification_requests` row plus one
  /// `verification_results` row per selected credential type.
  ///
  /// [claimsByCredentialTypeId] is what the organisation worker typed in
  /// for each credential -- what the applicant's own paperwork/external
  /// application says (see `claimFieldsForType`) -- written into
  /// `verification_results.claimed_value` right here at request time. No
  /// decision is made yet: `VerificationRepository.startVerification`/
  /// `completeVerification` do the actual automated comparison against the
  /// real department records later.
  /// Requires `consent_grants_insert_organisation`,
  /// `verification_requests_insert_org`, and `verification_results_insert_org`.
  Future<String> requestVerification({
    required String citizenId,
    required List<String> credentialTypeIds,
    Map<String, Map<String, dynamic>> claimsByCredentialTypeId = const {},
  }) async {
    final row = await _orgUserRow();
    final organisation = row['organisations'] as Map<String, dynamic>?;
    final organisationId = organisation?['organisation_id'] as String?;
    if (organisationId == null) {
      throw const AppException('No organisation is linked to this account.');
    }
    final requestedByUserId = row['organisation_user_id'] as String;

    final consentRow = await _client
        .from('consent_grants')
        .insert({
          'citizen_id': citizenId,
          'organisation_id': organisationId,
          'scope': {'credential_type_ids': credentialTypeIds},
        })
        .select('consent_id')
        .single();
    final consentId = consentRow['consent_id'] as String;

    final requestRow = await _client
        .from('verification_requests')
        .insert({
          'citizen_id': citizenId,
          'organisation_id': organisationId,
          'requested_by_user_id': requestedByUserId,
          'consent_id': consentId,
          'overall_status': 'pending',
          'requested_at': DateTime.now().toIso8601String(),
        })
        .select('request_id')
        .single();
    final requestId = requestRow['request_id'] as String;

    if (credentialTypeIds.isNotEmpty) {
      await _client.from('verification_results').insert([
        for (final credentialTypeId in credentialTypeIds)
          {
            'request_id': requestId,
            'credential_type_id': credentialTypeId,
            'match_status': 'pending',
            if (claimsByCredentialTypeId[credentialTypeId] != null)
              'claimed_value': claimsByCredentialTypeId[credentialTypeId],
          },
      ]);
    }

    return requestId;
  }

  /// "Offer Employment" -- via the `offer_employment` RPC (docs/database/
  /// offer_employment_records_with_labour.sql), which does two things in
  /// one call: creates the organisation's own HR record
  /// (`organisation_employees`) -- always succeeds, it's their own
  /// internal note -- and records the citizen as 'Employed' with
  /// Employment and Labour's own `labour_employment_records` too, unless
  /// they're currently enrolled full-time (same rule an official's own
  /// record-employment action enforces), in which case the government
  /// record is skipped rather than the whole offer failing.
  /// [sourceVerificationRequestId] just records which verification led to
  /// the offer, for traceability -- not required.
  Future<OfferEmploymentResult> offerEmployment({
    required String citizenId,
    required String jobTitle,
    String? departmentOrPosition,
    num? salary,
    required String salaryFrequency,
    required DateTime startDate,
    String? sourceVerificationRequestId,
  }) async {
    final result = await _client.rpc('offer_employment', params: {
      'p_citizen_id': citizenId,
      'p_job_title': jobTitle,
      'p_department_or_position': departmentOrPosition,
      'p_salary': salary,
      'p_salary_frequency': salaryFrequency,
      'p_start_date': startDate.toIso8601String().split('T').first,
      'p_source_verification_request_id': sourceVerificationRequestId,
    }) as Map<String, dynamic>;
    return OfferEmploymentResult(
      labourRecorded: result['labour_recorded'] as bool? ?? false,
      skipReason: result['skip_reason'] as String?,
    );
  }

  Future<List<OrganisationEmployeeItem>> getEmployees() async {
    final row = await _orgUserRow();
    final organisation = row['organisations'] as Map<String, dynamic>?;
    final organisationId = organisation?['organisation_id'] as String?;
    if (organisationId == null) return [];
    final rows = await _client
        .from('organisation_employees')
        .select('employee_id, job_title, department_or_position, salary, salary_frequency, '
            'employment_status, start_date, citizens(first_name, last_name, id_number)')
        .eq('organisation_id', organisationId)
        .order('start_date', ascending: false);
    return [for (final r in rows) OrganisationEmployeeItem.fromRow(r)];
  }

  Future<OrganisationDashboardStats> getDashboardStats() async {
    final row = await _orgUserRow();
    final organisation = row['organisations'] as Map<String, dynamic>?;
    final organisationId = organisation?['organisation_id'] as String?;

    var pending = 0;
    var completedThisMonth = 0;
    if (organisationId != null) {
      final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1).toIso8601String();
      final requests = await _client
          .from('verification_requests')
          .select('overall_status, responded_at')
          .eq('organisation_id', organisationId);

      for (final request in requests) {
        // 'in_review'/'approved' are not valid overall_status values
        // (confirmed live via verification_status_check); 'processing' and
        // 'completed' are the real in-flight/terminal-success states.
        final status = request['overall_status'] as String? ?? '';
        if (status == 'pending' || status == 'processing') pending++;
        final respondedAt = request['responded_at'] as String?;
        final isDecided = status == 'completed' || status == 'rejected';
        if (isDecided && respondedAt != null && respondedAt.compareTo(monthStart) >= 0) {
          completedThisMonth++;
        }
      }
    }

    return OrganisationDashboardStats(
      organisationName: organisation?['legal_name'] as String? ?? 'Organisation',
      accessTier: organisation?['access_tier'] as String? ?? 'standard',
      verified: organisation?['verified'] as bool? ?? false,
      pendingVerifications: pending,
      completedThisMonth: completedThisMonth,
    );
  }
}

class OrganisationApplicationStatus {
  const OrganisationApplicationStatus({
    required this.organisationId,
    required this.legalName,
    required this.registrationStatus,
    required this.isHead,
    this.declineReason,
  });

  final String organisationId;
  final String legalName;

  /// 'pending' | 'approved' | 'declined'.
  final String registrationStatus;
  final String? declineReason;
  final bool isHead;
}

class CredentialTypeOption {
  const CredentialTypeOption({
    required this.credentialTypeId,
    required this.typeCode,
    required this.displayName,
    required this.issuingDepartment,
  });

  final String credentialTypeId;
  final String typeCode;
  final String displayName;
  final String issuingDepartment;
}

/// Result of [OrganisationRepository.offerEmployment] -- whether
/// Employment and Labour's own official record was also updated, and why
/// not if it wasn't (still enrolled full-time).
class OfferEmploymentResult {
  const OfferEmploymentResult({required this.labourRecorded, this.skipReason});

  final bool labourRecorded;
  final String? skipReason;
}

/// Mirrors `public.organisation_employees` -- one row the organisation
/// created via [OrganisationRepository.offerEmployment]. Also readable by
/// the citizen the row is about, via `organisation_employees_select`'s
/// `citizen_id = current_citizen_id()` branch.
class OrganisationEmployeeItem {
  const OrganisationEmployeeItem({
    required this.employeeId,
    required this.citizenFullName,
    required this.citizenIdNumber,
    required this.jobTitle,
    this.departmentOrPosition,
    this.salary,
    required this.salaryFrequency,
    required this.employmentStatus,
    required this.startDate,
  });

  final String employeeId;
  final String citizenFullName;
  final String citizenIdNumber;
  final String jobTitle;
  final String? departmentOrPosition;
  final num? salary;
  final String salaryFrequency;
  final String employmentStatus;
  final DateTime startDate;

  factory OrganisationEmployeeItem.fromRow(Map<String, dynamic> row) {
    final citizen = row['citizens'] as Map<String, dynamic>?;
    final name = '${citizen?['first_name'] ?? ''} ${citizen?['last_name'] ?? ''}'.trim();
    return OrganisationEmployeeItem(
      employeeId: row['employee_id'] as String,
      citizenFullName: name.isEmpty ? 'Unknown citizen' : name,
      citizenIdNumber: citizen?['id_number'] as String? ?? '',
      jobTitle: row['job_title'] as String? ?? '',
      departmentOrPosition: row['department_or_position'] as String?,
      salary: row['salary'] as num?,
      salaryFrequency: row['salary_frequency'] as String? ?? 'Monthly',
      employmentStatus: row['employment_status'] as String? ?? 'Active',
      startDate: DateTime.tryParse(row['start_date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class OrganisationCitizenSearchResult {
  const OrganisationCitizenSearchResult({
    required this.citizenId,
    required this.fullName,
    required this.idNumber,
    required this.currentStatus,
  });

  final String citizenId;
  final String fullName;
  final String idNumber;
  final String currentStatus;
}

/// A credential an organisation can select to include in a verification
/// request -- deliberately a narrower shape than `CredentialItem` (no
/// issued/expiry dates), since an organisation isn't shown the citizen's
/// full credential record, only enough to pick what to verify.
class VerifiableCredential {
  const VerifiableCredential({
    required this.credentialTypeId,
    required this.typeCode,
    required this.typeName,
    required this.issuingDepartment,
    required this.status,
    this.qualification,
  });

  final String credentialTypeId;

  /// e.g. 'NSC', 'DRIVERS_LICENCE' -- drives which claim fields
  /// `claimFieldsForType` asks the organisation worker to fill in before
  /// submitting a verification request for this credential.
  final String typeCode;
  final String typeName;
  final String issuingDepartment;
  final String status;

  /// The real record behind an NSC/TERTIARY_QUALIFICATION credential --
  /// see `fetchQualificationDetail`. `null` for every other credential type.
  final QualificationDetail? qualification;
}

final organisationRepositoryProvider = Provider<OrganisationRepository>((ref) {
  ref.watch(authStateChangesProvider);
  return OrganisationRepository(ref.watch(supabaseClientProvider));
});

final organisationDashboardStatsProvider = FutureProvider.autoDispose<OrganisationDashboardStats>((ref) {
  return ref.watch(organisationRepositoryProvider).getDashboardStats();
});

final organisationEmployeesProvider = FutureProvider.autoDispose<List<OrganisationEmployeeItem>>((ref) {
  return ref.watch(organisationRepositoryProvider).getEmployees();
});

typedef CitizenSearchQuery = ({String idNumber, String? firstName, String? lastName});

final citizenSearchResultProvider =
    FutureProvider.autoDispose.family<List<OrganisationCitizenSearchResult>, CitizenSearchQuery>((ref, query) {
  return ref.watch(organisationRepositoryProvider).searchCitizens(
        idNumber: query.idNumber,
        firstName: query.firstName,
        lastName: query.lastName,
      );
});

final citizenVerifiableCredentialsProvider =
    FutureProvider.autoDispose.family<List<VerifiableCredential>, String>((ref, citizenId) {
  return ref.watch(organisationRepositoryProvider).getCitizenCredentialsForVerification(citizenId);
});

final organisationApplicationStatusProvider = FutureProvider.autoDispose<OrganisationApplicationStatus>((ref) {
  return ref.watch(organisationRepositoryProvider).getApplicationStatus();
});

final allCredentialTypesProvider = FutureProvider.autoDispose<List<CredentialTypeOption>>((ref) {
  return ref.watch(organisationRepositoryProvider).getAllCredentialTypes();
});

final myCredentialScopeProvider = FutureProvider.autoDispose<List<CredentialTypeOption>>((ref) {
  return ref.watch(organisationRepositoryProvider).getMyCredentialScope();
});

final organisationColleaguesProvider = FutureProvider.autoDispose<List<OrganisationColleagueItem>>((ref) {
  return ref.watch(organisationRepositoryProvider).getColleagues();
});

final myOrgRoleProvider = FutureProvider.autoDispose<String>((ref) {
  return ref.watch(organisationRepositoryProvider).getMyRole();
});
