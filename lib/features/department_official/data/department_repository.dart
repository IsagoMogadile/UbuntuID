import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../routing/app_routes.dart';
import '../../../services/service_providers.dart';
import '../../shared/domain/citizen_lookup_result.dart';
import '../domain/department_category.dart';
import '../domain/department_dashboard_stats.dart';
import '../domain/department_record_config.dart';

/// Real Supabase-backed department-official data source. Schema reference:
/// docs/SCREEN_DATABASE_MAP.md §3 and docs/DATA_MODEL.md.
/// `department_officials.department_id` is confirmed live.
class DepartmentRepository {
  DepartmentRepository(this._client);

  final SupabaseClient _client;
  Future<Map<String, dynamic>>? _officialRowFuture;

  Future<Map<String, dynamic>> _officialRow() {
    return _officialRowFuture ??= () async {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw const AppException('You are not signed in.');
      final row = await _client
          .from('department_officials')
          .select('official_id, full_name, official_role, active, department_id, '
              'departments(department_id, department_name, department_code, category, active)')
          .eq('auth_user_id', userId)
          .maybeSingle();
      if (row == null) {
        throw const AppException('No department official record is linked to this account.');
      }
      return row;
    }();
  }

  Future<DepartmentOfficialProfile> getProfile() async {
    final row = await _officialRow();
    final department = row['departments'] as Map<String, dynamic>?;
    final departmentName = department?['department_name'] as String? ?? 'Department';
    return DepartmentOfficialProfile(
      fullName: row['full_name'] as String? ?? '',
      officialRole: row['official_role'] as String? ?? 'Official',
      active: row['active'] as bool? ?? true,
      departmentId: row['department_id'] as String? ?? '',
      departmentName: departmentName,
      departmentCode: department?['department_code'] as String? ?? '',
      departmentCategory: department?['category'] as String?,
      category: DepartmentCategory.fromName(departmentName),
    );
  }

  // ---------------------------------------------------------------------
  // Generic department-record management -- backs the department-specific
  // record screens (register a marriage, issue a licence, record a tax
  // return, etc.), configured per department in
  // `lib/features/department_official/domain/department_record_config.dart`.
  // ---------------------------------------------------------------------

  /// Rows in [table] matching a single equality filter -- used for the
  /// simple one-column-per-citizen tables (`national_id_number`,
  /// `owner_id`, `spouse_1_id`).
  Future<List<Map<String, dynamic>>> getRecordsByColumn({
    required String table,
    required String column,
    required String value,
  }) {
    return _client.from(table).select().eq(column, value).order('created_at', ascending: false);
  }

  Future<void> insertRecord({required String table, required Map<String, dynamic> data}) {
    return _client.from(table).insert(data);
  }

  /// Generic update-by-primary-key, mirroring [insertRecord] -- backs the
  /// "edit"/"revoke"/"renew" actions on the department record screens
  /// (e.g. flipping a passport's status to Revoked). RLS already grants the
  /// owning department's officials (and admins) `ALL` on every department
  /// table, so this needs no new RPC.
  Future<void> updateRecord({
    required String table,
    required String idColumn,
    required dynamic idValue,
    required Map<String, dynamic> data,
  }) {
    return _client.from(table).update(data).eq(idColumn, idValue);
  }

  /// Generic delete-by-primary-key -- backs "remove" actions (e.g. SASSA
  /// grant removal). Same RLS coverage as [updateRecord].
  Future<void> deleteRecord({
    required String table,
    required String idColumn,
    required dynamic idValue,
  }) {
    return _client.from(table).delete().eq(idColumn, idValue);
  }

  // ---------------------------------------------------------------------
  // Credential mirror -- `credentials` is the cross-department verification
  // spine the citizen's Digital Identity screen, the organisation
  // verification flow, and admin oversight all read. Writing a matching
  // `credentials` row alongside the department-specific detail table is an
  // application-level convention with no database trigger backing it (see
  // docs/DATA_MODEL.md) -- these two helpers are that convention, called
  // from every issue/update method below so a real official action in the
  // app (not just the seed script) keeps both in sync. Previously only the
  // seed script did this, so a real "add a driver's licence" from this
  // screen never touched `credentials` -- the citizen's own Digital
  // Identity screen (and anything else reading `credentials`) never
  // reflected it.
  // ---------------------------------------------------------------------

  Future<Map<String, String>> _credentialTypeRef(String typeCode) async {
    final row = await _client
        .from('credential_types')
        .select('credential_type_id, issuing_department_id')
        .eq('type_code', typeCode)
        .single();
    return {
      'credential_type_id': row['credential_type_id'] as String,
      'issuing_department_id': row['issuing_department_id'] as String,
    };
  }

  Future<void> _issueCredentialMirror({
    required String citizenId,
    required String typeCode,
    required String status,
    DateTime? issuedDate,
    DateTime? expiryDate,
  }) async {
    final ref = await _credentialTypeRef(typeCode);
    await _client.from('credentials').insert({
      'citizen_id': citizenId,
      'credential_type_id': ref['credential_type_id'],
      'issuing_department_id': ref['issuing_department_id'],
      'status': status,
      'issued_date': (issuedDate ?? DateTime.now()).toIso8601String().split('T').first,
      if (expiryDate != null) 'expiry_date': expiryDate.toIso8601String().split('T').first,
    });
  }

  /// Updates the citizen's most recent `credentials` row for [typeCode] to
  /// [status] -- issues one instead if none exists yet (defensive: covers
  /// a record created before this mirroring existed).
  Future<void> _updateCredentialMirror({
    required String citizenId,
    required String typeCode,
    required String status,
    DateTime? expiryDate,
  }) async {
    final ref = await _credentialTypeRef(typeCode);
    final existing = await _client
        .from('credentials')
        .select('credential_id')
        .eq('citizen_id', citizenId)
        .eq('credential_type_id', ref['credential_type_id']!)
        .order('issued_date', ascending: false)
        .limit(1)
        .maybeSingle();
    if (existing != null) {
      await _client.from('credentials').update({
        'status': status,
        if (expiryDate != null) 'expiry_date': expiryDate.toIso8601String().split('T').first,
      }).eq('credential_id', existing['credential_id'] as String);
    } else {
      await _issueCredentialMirror(citizenId: citizenId, typeCode: typeCode, status: status, expiryDate: expiryDate);
    }
  }

  // ---------------------------------------------------------------------
  // Issue/update per record type -- the identifier (passport number,
  // licence number, VIN, tax number, case number, matric exam number) is
  // always server-generated (`next_*`/`generate_*` RPCs backed by real
  // Postgres sequences -- docs/database/auto_generated_official_identifiers.sql),
  // never typed by the official, since it's assigned by the issuing
  // department, not chosen by the applicant.
  // ---------------------------------------------------------------------

  Future<void> issuePassport({
    required String citizenId,
    required String nationalIdNumber,
    required DateTime issueDate,
    required DateTime expiryDate,
    required String status,
  }) async {
    final passportNumber = await _client.rpc('next_passport_number') as String;
    await _client.from('dha_passports').insert({
      'passport_number': passportNumber,
      'national_id_number': nationalIdNumber,
      'issue_date': issueDate.toIso8601String().split('T').first,
      'expiry_date': expiryDate.toIso8601String().split('T').first,
      'status': status,
    });
    await _issueCredentialMirror(
      citizenId: citizenId,
      typeCode: 'PASSPORT',
      status: _passportCredentialStatus(status),
      issuedDate: issueDate,
      expiryDate: expiryDate,
    );
  }

  Future<void> updatePassport({
    required String citizenId,
    required String passportNumber,
    required DateTime issueDate,
    required DateTime expiryDate,
    required String status,
  }) async {
    await updateRecord(table: 'dha_passports', idColumn: 'passport_number', idValue: passportNumber, data: {
      'issue_date': issueDate.toIso8601String().split('T').first,
      'expiry_date': expiryDate.toIso8601String().split('T').first,
      'status': status,
    });
    await _updateCredentialMirror(
      citizenId: citizenId,
      typeCode: 'PASSPORT',
      status: _passportCredentialStatus(status),
      expiryDate: expiryDate,
    );
  }

  static String _passportCredentialStatus(String status) => switch (status) {
        'Expired' => 'expired',
        'Revoked' => 'revoked',
        _ => 'active',
      };

  Future<void> issueDriversLicence({
    required String citizenId,
    required String nationalIdNumber,
    required String licenceCode,
    required DateTime issueDate,
    required DateTime expiryDate,
    required String status,
  }) async {
    final licenceNumber = await _client.rpc('next_licence_number') as String;
    await _client.from('dot_driver_licences').insert({
      'licence_number': licenceNumber,
      'national_id_number': nationalIdNumber,
      'licence_code': licenceCode,
      'issue_date': issueDate.toIso8601String().split('T').first,
      'expiry_date': expiryDate.toIso8601String().split('T').first,
      'status': status,
    });
    await _issueCredentialMirror(
      citizenId: citizenId,
      typeCode: 'DRIVERS_LICENCE',
      status: _licenceCredentialStatus(status),
      issuedDate: issueDate,
      expiryDate: expiryDate,
    );
  }

  Future<void> updateDriversLicence({
    required String citizenId,
    required String licenceNumber,
    required String licenceCode,
    required DateTime issueDate,
    required DateTime expiryDate,
    required String status,
  }) async {
    await updateRecord(table: 'dot_driver_licences', idColumn: 'licence_number', idValue: licenceNumber, data: {
      'licence_code': licenceCode,
      'issue_date': issueDate.toIso8601String().split('T').first,
      'expiry_date': expiryDate.toIso8601String().split('T').first,
      'status': status,
    });
    await _updateCredentialMirror(
      citizenId: citizenId,
      typeCode: 'DRIVERS_LICENCE',
      status: _licenceCredentialStatus(status),
      expiryDate: expiryDate,
    );
  }

  static String _licenceCredentialStatus(String status) => switch (status) {
        'Suspended' => 'suspended',
        'Expired' => 'expired',
        'Revoked' => 'revoked',
        _ => 'active',
      };

  Future<void> registerVehicle({
    required String nationalIdNumber,
    required String make,
    required String model,
    required int year,
    required DateTime discExpiryDate,
  }) async {
    final vin = await _client.rpc('generate_vin_number') as String;
    final plate = await _client.rpc('generate_registration_number') as String;
    await _client.from('dot_vehicles').insert({
      'vin_number': vin,
      'registration_number': plate,
      'owner_id': nationalIdNumber,
      'make': make,
      'model': model,
      'year': year,
      'disc_expiry_date': discExpiryDate.toIso8601String().split('T').first,
    });
  }

  Future<void> registerTaxpayer({
    required String citizenId,
    required String nationalIdNumber,
    required String complianceStatus,
    required DateTime registeredDate,
  }) async {
    final taxNumber = await _client.rpc('next_tax_number') as String;
    await _client.from('sars_taxpayers').insert({
      'tax_number': taxNumber,
      'national_id_number': nationalIdNumber,
      'tax_compliance_status': complianceStatus,
      'registered_date': registeredDate.toIso8601String().split('T').first,
    });
    await _issueCredentialMirror(
      citizenId: citizenId,
      typeCode: 'TAX_COMPLIANCE',
      status: complianceStatus == 'Compliant' ? 'active' : 'suspended',
      issuedDate: registeredDate,
    );
  }

  Future<void> updateTaxpayerCompliance({
    required String citizenId,
    required String taxNumber,
    required String complianceStatus,
    DateTime? registeredDate,
  }) async {
    await updateRecord(
      table: 'sars_taxpayers',
      idColumn: 'tax_number',
      idValue: taxNumber,
      data: {
        'tax_compliance_status': complianceStatus,
        if (registeredDate != null) 'registered_date': registeredDate.toIso8601String().split('T').first,
      },
    );
    await _updateCredentialMirror(
      citizenId: citizenId,
      typeCode: 'TAX_COMPLIANCE',
      status: complianceStatus == 'Compliant' ? 'active' : 'suspended',
    );
  }

  Future<void> recordCriminalCase({
    required String nationalIdNumber,
    required String offenceCode,
    required DateTime convictionDate,
    required String sentenceStatus,
  }) async {
    final caseNumber = await _client.rpc('next_case_number') as String;
    await _client.from('saps_criminal_records').insert({
      'case_number': caseNumber,
      'national_id_number': nationalIdNumber,
      'offence_code': offenceCode,
      'conviction_date': convictionDate.toIso8601String().split('T').first,
      'sentence_status': sentenceStatus,
    });
  }

  Future<void> issueClearanceCertificate({
    required String citizenId,
    required String nationalIdNumber,
    required DateTime issueDate,
    required String status,
  }) async {
    await _client.from('saps_clearance_certificates').insert({
      'national_id_number': nationalIdNumber,
      'issue_date': issueDate.toIso8601String().split('T').first,
      'status': status,
    });
    await _issueCredentialMirror(
      citizenId: citizenId,
      typeCode: 'CRIMINAL_CLEARANCE',
      status: status == 'Clear' ? 'active' : 'suspended',
      issuedDate: issueDate,
    );
  }

  Future<void> issueMatricCertificate({
    required String citizenId,
    required String nationalIdNumber,
    required int year,
    required String overallPassStatus,
  }) async {
    final examNumber = await _client.rpc('next_matric_exam_number') as String;
    await _client.from('dbe_nsc_results').insert({
      'matric_exam_number': examNumber,
      'national_id_number': nationalIdNumber,
      'year': year,
      'overall_pass_status': overallPassStatus,
    });
    await _issueCredentialMirror(
      citizenId: citizenId,
      typeCode: 'NSC',
      status: 'active',
      issuedDate: DateTime(year, 1, 10),
    );
  }

  /// Goes through the `enrol_student` RPC (docs/database/
  /// cross_department_eligibility_checks.sql) rather than a raw INSERT --
  /// it rejects server-side unless the citizen already has a matric (NSC)
  /// record with Basic Education, or [matureAgeExemption] is set with a
  /// [matureAgeExemptionReason] (which also raises a `flagged_records` entry
  /// for admin review).
  Future<void> enrolStudent({
    required String citizenId,
    required String nationalIdNumber,
    required String institutionCode,
    required String qualificationName,
    required String completionStatus,
    required String studyMode,
    bool matureAgeExemption = false,
    String? matureAgeExemptionReason,
  }) async {
    await _client.rpc('enrol_student', params: {
      'p_citizen_id': citizenId,
      'p_national_id_number': nationalIdNumber,
      'p_institution_code': institutionCode,
      'p_qualification_name': qualificationName,
      'p_completion_status': completionStatus,
      'p_study_mode': studyMode,
      'p_mature_age_exemption': matureAgeExemption,
      'p_mature_age_exemption_reason': matureAgeExemptionReason,
    });
    // Same LABOUR_STATUS-style bug avoided here: a citizen can legitimately
    // have more than one enrolment over their life (undergrad, then later a
    // postgrad) -- update the one TERTIARY_QUALIFICATION credential that
    // should exist rather than inserting a new mirror row every time.
    await _updateCredentialMirror(
      citizenId: citizenId,
      typeCode: 'TERTIARY_QUALIFICATION',
      status: completionStatus == 'Graduated' ? 'active' : 'pending',
    );
  }

  /// A completed qualification's actual result -- distinct from
  /// [enrolStudent]'s in-progress enrolment status, and the more
  /// authoritative of the two when both exist for the same citizen (a
  /// finished degree with a real result outranks "still enrolled"). Shares
  /// the same TERTIARY_QUALIFICATION credential mirror as enrolment, kept
  /// current via _updateCredentialMirror rather than a second row.
  Future<void> recordAcademicResult({
    required String citizenId,
    required String nationalIdNumber,
    required String institutionCode,
    required String qualificationName,
    required int year,
    required String finalResult,
  }) async {
    await _client.from('dhet_academic_records').insert({
      'national_id_number': nationalIdNumber,
      'institution_code': institutionCode,
      'qualification_name': qualificationName,
      'year': year,
      'final_result': finalResult,
    });
    await _updateCredentialMirror(
      citizenId: citizenId,
      typeCode: 'TERTIARY_QUALIFICATION',
      status: finalResult == 'Fail' ? 'suspended' : 'active',
    );
  }

  Future<void> updateStudentEnrolment({
    required String citizenId,
    required String enrollmentId,
    required String completionStatus,
    String? institutionCode,
    String? qualificationName,
    String? studyMode,
  }) async {
    await updateRecord(
      table: 'dhet_student_enrollment',
      idColumn: 'enrollment_id',
      idValue: enrollmentId,
      data: {
        'completion_status': completionStatus,
        if (institutionCode != null) 'institution_code': institutionCode,
        if (qualificationName != null) 'qualification_name': qualificationName,
        if (studyMode != null) 'study_mode': studyMode,
      },
    );
    await _updateCredentialMirror(
      citizenId: citizenId,
      typeCode: 'TERTIARY_QUALIFICATION',
      status: completionStatus == 'Graduated' ? 'active' : 'pending',
    );
  }

  /// Goes through the `issue_nsfas_funding` RPC (docs/database/
  /// cross_department_eligibility_checks.sql) rather than a raw INSERT --
  /// approving funding (`approvedStatus: true`) is rejected server-side
  /// unless the citizen has an active ("Enrolled") enrolment and no active
  /// employment record. Recording a non-approved application always
  /// succeeds (that's itself a valid, auditable outcome).
  Future<void> issueNsfasFunding({
    required String nationalIdNumber,
    required int fundingYear,
    required bool approvedStatus,
    required num disbursedAmount,
  }) {
    return _client.rpc('issue_nsfas_funding', params: {
      'p_national_id_number': nationalIdNumber,
      'p_funding_year': fundingYear,
      'p_approved_status': approvedStatus,
      'p_disbursed_amount': disbursedAmount,
    });
  }

  Future<void> issueSassaGrant({
    required String citizenId,
    required String nationalIdNumber,
    required String grantType,
    required String status,
    required String payoutMethod,
  }) async {
    await _client.from('sassa_grants').insert({
      'national_id_number': nationalIdNumber,
      'grant_type': grantType,
      'status': status,
      'payout_method': payoutMethod,
    });
    await _issueCredentialMirror(citizenId: citizenId, typeCode: 'SASSA_STATUS', status: status.toLowerCase());
  }

  Future<void> updateSassaGrant({
    required String citizenId,
    required String grantId,
    required String grantType,
    required String status,
    required String payoutMethod,
  }) async {
    await updateRecord(table: 'sassa_grants', idColumn: 'grant_id', idValue: grantId, data: {
      'grant_type': grantType,
      'status': status,
      'payout_method': payoutMethod,
    });
    await _updateCredentialMirror(citizenId: citizenId, typeCode: 'SASSA_STATUS', status: status.toLowerCase());
  }

  Future<void> removeSassaGrant({required String citizenId, required String grantId}) async {
    await deleteRecord(table: 'sassa_grants', idColumn: 'grant_id', idValue: grantId);
    await _updateCredentialMirror(citizenId: citizenId, typeCode: 'SASSA_STATUS', status: 'revoked');
  }

  /// Goes through the `record_employment` RPC (docs/database/
  /// cross_department_eligibility_checks.sql) rather than a raw INSERT --
  /// it rejects server-side when [employmentStatus] is Employed/
  /// Self-Employed and the citizen is currently enrolled *full-time* with
  /// DHET (part-time enrolment, or no active enrolment, is unaffected).
  Future<void> recordEmployment({
    required String citizenId,
    required String nationalIdNumber,
    String? employerName,
    required String employmentStatus,
    DateTime? startDate,
    required num uifContributionAmount,
    required String uifClaimStatus,
  }) async {
    await _client.rpc('record_employment', params: {
      'p_national_id_number': nationalIdNumber,
      'p_employer_name': employerName,
      'p_employment_status': employmentStatus,
      'p_start_date': startDate?.toIso8601String().split('T').first,
      'p_uif_contribution_amount': uifContributionAmount,
      'p_uif_claim_status': uifClaimStatus,
    });
    // Unlike passport/licence/tax (one-time "issue" events), a citizen can
    // have several employment records over time (job changes) -- but there
    // should only ever be one LABOUR_STATUS credential reflecting their
    // *current* status, not one per job. _updateCredentialMirror finds and
    // updates the existing one (or creates it the first time) instead of
    // always inserting a new row.
    await _updateCredentialMirror(
      citizenId: citizenId,
      typeCode: 'LABOUR_STATUS',
      status: employmentStatus == 'Unemployed' ? 'suspended' : 'active',
    );
  }

  Future<void> updateEmployment({
    required String citizenId,
    required String recordId,
    String? employerName,
    required String employmentStatus,
    required num uifContributionAmount,
    required String uifClaimStatus,
    DateTime? startDate,
  }) async {
    await updateRecord(table: 'labour_employment_records', idColumn: 'record_id', idValue: recordId, data: {
      'employer_name': employerName,
      'employment_status': employmentStatus,
      'uif_contribution_amount': uifContributionAmount,
      'uif_claim_status': uifClaimStatus,
      if (startDate != null) 'start_date': startDate.toIso8601String().split('T').first,
    });
    await _updateCredentialMirror(
      citizenId: citizenId,
      typeCode: 'LABOUR_STATUS',
      status: employmentStatus == 'Unemployed' ? 'suspended' : 'active',
    );
  }

  // ---------------------------------------------------------------------
  // Human Settlements (`DHS`) -- properties/title deeds/housing
  // applications already had department-scoped RLS prepared (`current_
  // official_department_code() = 'DHS'`) from an earlier session, but no
  // `departments` row with that code existed yet, and no official-facing
  // screen read/wrote these tables -- see docs/database/
  // add_human_settlements_department.sql.
  // ---------------------------------------------------------------------

  /// A property doesn't have a `citizen_id` column of its own -- it's
  /// reached through `housing_beneficiaries`, same join
  /// `CitizenRepository.getHousingBeneficiaryProperties` uses on the
  /// citizen side.
  Future<List<Map<String, dynamic>>> getPropertyForCitizen(String citizenId) async {
    final rows = await _client
        .from('housing_beneficiaries')
        .select('housing_beneficiary_id, beneficiary_role, properties(*, title_deeds(*))')
        .eq('citizen_id', citizenId)
        .eq('active', true);
    return [
      for (final row in rows)
        if (row['properties'] != null) {...row['properties'] as Map<String, dynamic>, '_beneficiary_role': row['beneficiary_role']},
    ];
  }

  /// Creates the property **and** links this citizen to it as the owning
  /// beneficiary in one call -- a property with no beneficiary isn't a
  /// meaningful state for this screen (the citizen side only ever reads
  /// properties through `housing_beneficiaries`).
  Future<void> registerProperty({
    required String citizenId,
    String? township,
    String? suburb,
    String? city,
    required String municipality,
    required String province,
    String? propertyType,
    required String housingStatus,
    num? propertyValue,
  }) async {
    final reference = await _client.rpc('next_property_reference') as String;
    final propertyRow = await _client
        .from('properties')
        .insert({
          'property_reference': reference,
          'township': township,
          'suburb': suburb,
          'city': city,
          'municipality': municipality,
          'province': province,
          'property_type': propertyType,
          'housing_status': housingStatus,
          'property_value': propertyValue,
        })
        .select('property_id')
        .single();
    await _client.from('housing_beneficiaries').insert({
      'citizen_id': citizenId,
      'property_id': propertyRow['property_id'],
      'beneficiary_role': 'owner',
      'start_date': DateTime.now().toIso8601String().split('T').first,
      'active': true,
    });
  }

  Future<void> updatePropertyStatus({
    required String propertyId,
    required String housingStatus,
    String? municipality,
    String? province,
    String? suburb,
    String? propertyType,
  }) {
    return updateRecord(
      table: 'properties',
      idColumn: 'property_id',
      idValue: propertyId,
      data: {
        'housing_status': housingStatus,
        if (municipality != null) 'municipality': municipality,
        if (province != null) 'province': province,
        if (suburb != null) 'suburb': suburb,
        if (propertyType != null) 'property_type': propertyType,
      },
    );
  }

  /// Title deeds for the property this citizen is a beneficiary of --
  /// there's no direct citizen column on `title_deeds`, only via
  /// `properties`, so this can't use the generic `getRecordsByColumn`.
  Future<List<Map<String, dynamic>>> getTitleDeedsForCitizen(String citizenId) async {
    final propertyRows = await getPropertyForCitizen(citizenId);
    if (propertyRows.isEmpty) return [];
    final propertyId = propertyRows.first['property_id'] as String;
    return _client.from('title_deeds').select().eq('property_id', propertyId).order('created_at', ascending: false);
  }

  /// Looks up the citizen's own property first -- a title deed with no
  /// property to attach to isn't a meaningful state, and the "Title Deed"
  /// record type's form has no property picker of its own (register the
  /// property first).
  Future<void> issueTitleDeedForCitizen({
    required String citizenId,
    required String deedType,
    required String registeredOwnerName,
    required DateTime registrationDate,
  }) async {
    final propertyRows = await getPropertyForCitizen(citizenId);
    if (propertyRows.isEmpty) {
      throw const AppException('Register a property for this citizen before issuing a title deed.');
    }
    final deedNumber = await _client.rpc('generate_title_deed_number') as String;
    await _client.from('title_deeds').insert({
      'property_id': propertyRows.first['property_id'],
      'title_deed_number': deedNumber,
      'deed_type': deedType,
      'registered_owner_name': registeredOwnerName,
      'registration_date': registrationDate.toIso8601String().split('T').first,
      'registration_status': 'registered',
      'deed_status': 'active',
      'deed_issued_date': registrationDate.toIso8601String().split('T').first,
    });
  }

  Future<void> submitHousingApplication({
    required String citizenId,
    required String programmeCode,
    required String municipality,
    required String province,
    int? householdSize,
    num? householdIncome,
  }) async {
    final reference = await _client.rpc('generate_housing_application_reference') as String;
    final programme =
        await _client.from('housing_programmes').select('programme_id').eq('programme_code', programmeCode).single();
    await _client.from('housing_applications').insert({
      'citizen_id': citizenId,
      'programme_id': programme['programme_id'],
      'application_reference': reference,
      'application_status': 'submitted',
      'application_date': DateTime.now().toIso8601String().split('T').first,
      'municipality': municipality,
      'province': province,
      'household_size': householdSize,
      'household_income': householdIncome,
    });
  }

  Future<void> updateHousingApplicationStatus({
    required String housingApplicationId,
    required String applicationStatus,
    String? programmeCode,
    String? municipality,
    String? province,
    int? householdSize,
    num? householdIncome,
  }) {
    return updateRecord(
      table: 'housing_applications',
      idColumn: 'housing_application_id',
      idValue: housingApplicationId,
      data: {
        'application_status': applicationStatus,
        if (applicationStatus == 'approved') 'approved_date': DateTime.now().toIso8601String().split('T').first,
        if (applicationStatus == 'rejected') 'rejected_date': DateTime.now().toIso8601String().split('T').first,
        if (programmeCode != null) 'programme_code': programmeCode,
        if (municipality != null) 'municipality': municipality,
        if (province != null) 'province': province,
        if (householdSize != null) 'household_size': householdSize,
        if (householdIncome != null) 'household_income': householdIncome,
      },
    );
  }

  /// Home Affairs only -- registers a marriage via the `register_marriage`
  /// SECURITY DEFINER RPC, which rejects the attempt server-side if either
  /// citizen is already recorded as married (docs/database
  /// /register_marriage.sql) rather than trusting a client-side check.
  Future<void> registerMarriage({
    required String spouse1Id,
    required String spouse2Id,
    required String marriageType,
    required DateTime dateOfMarriage,
  }) {
    return _client.rpc('register_marriage', params: {
      'p_spouse_1_id': spouse1Id,
      'p_spouse_2_id': spouse2Id,
      'p_marriage_type': marriageType,
      'p_date_of_marriage': dateOfMarriage.toIso8601String().split('T').first,
    });
  }

  /// Home Affairs only -- full citizen row for the "Edit Citizen" form
  /// (includes `gender`/`citizenship_status`, which `CitizenLookupResult`
  /// deliberately omits since it's shared with every department's generic
  /// search).
  Future<Map<String, dynamic>> getCitizenForEdit(String citizenId) {
    return _client
        .from('citizens')
        .select('citizen_id, first_name, last_name, id_number, date_of_birth, phone_number, email, '
            'gender, citizenship_status')
        .eq('citizen_id', citizenId)
        .single();
  }

  /// Home Affairs only -- edits a citizen's own identity record (name,
  /// date of birth, contact details, gender, citizenship status). Gated by
  /// the live `citizens_update` RLS policy (same `HOME_AFFAIRS`-official-or
  /// -admin check as `citizens_insert`) -- confirmed live, no RPC needed.
  Future<void> updateCitizenDetails({
    required String citizenId,
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    String? phoneNumber,
    String? email,
    String? gender,
    String? citizenshipStatus,
  }) {
    return _client.from('citizens').update({
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'phone_number': phoneNumber,
      'email': email,
      'gender': gender,
      'citizenship_status': citizenshipStatus,
    }).eq('citizen_id', citizenId);
  }

  // ---------------------------------------------------------------------
  // SAPS -- Wanted Persons and Offenders are department-wide lists, not
  // per-citizen records, so they don't fit `RecordTypeConfig` and get
  // their own screens/methods.
  // ---------------------------------------------------------------------

  Future<List<WantedPersonItem>> getWantedPersons() async {
    final rows = await _client
        .from('saps_wanted_persons')
        .select('wanted_id, national_id_number, reason, date_listed, status, apprehended_date, '
            'citizens!saps_wanted_persons_national_id_number_fkey(first_name, last_name)')
        .order('date_listed', ascending: false);
    return [
      for (final r in rows)
        WantedPersonItem(
          wantedId: r['wanted_id'] as String,
          idNumber: r['national_id_number'] as String,
          fullName: '${r['citizens']?['first_name'] ?? ''} ${r['citizens']?['last_name'] ?? ''}'.trim(),
          reason: r['reason'] as String? ?? '',
          dateListed: DateTime.tryParse(r['date_listed'] as String? ?? '') ?? DateTime.now(),
          status: r['status'] as String? ?? 'Wanted',
        ),
    ];
  }

  Future<void> addWantedPerson({required String idNumber, required String reason}) {
    return _client.from('saps_wanted_persons').insert({
      'national_id_number': idNumber,
      'reason': reason,
    });
  }

  Future<void> setWantedStatus({required String wantedId, required String status}) {
    return _client.from('saps_wanted_persons').update({
      'status': status,
      if (status != 'Wanted') 'apprehended_date': DateTime.now().toIso8601String().split('T').first,
    }).eq('wanted_id', wantedId);
  }

  Future<List<OffenderItem>> getOffenders() async {
    final rows = await _client
        .from('saps_criminal_records')
        .select('case_number, national_id_number, offence_code, conviction_date, sentence_status, '
            'citizens!saps_criminal_records_national_id_number_fkey(first_name, last_name)')
        .order('conviction_date', ascending: false);
    return [
      for (final r in rows)
        OffenderItem(
          caseNumber: r['case_number'] as String,
          idNumber: r['national_id_number'] as String,
          fullName: '${r['citizens']?['first_name'] ?? ''} ${r['citizens']?['last_name'] ?? ''}'.trim(),
          offenceCode: r['offence_code'] as String? ?? '',
          convictionDate: DateTime.tryParse(r['conviction_date'] as String? ?? '') ?? DateTime.now(),
          sentenceStatus: r['sentence_status'] as String? ?? '',
        ),
    ];
  }

  /// Home Affairs only -- records a death (`dha_death_records`, same shape
  /// as the raw `insertRecord` path it replaces for the "Death" record
  /// type) and, in the same server-side call, raises a `flagged_records`
  /// entry so a UbuntuID administrator is notified to review and
  /// deactivate the citizen's account. Via the `declare_citizen_deceased`
  /// SECURITY DEFINER RPC -- see docs/database/declare_citizen_deceased.sql
  /// (must be applied to the database before this will work; re-checks
  /// `HOME_AFFAIRS` department membership server-side).
  Future<void> declareCitizenDeceased({
    required String citizenId,
    required DateTime dateOfDeath,
    required String placeOfDeath,
    required String causeCode,
  }) {
    return _client.rpc('declare_citizen_deceased', params: {
      'p_citizen_id': citizenId,
      'p_date_of_death': dateOfDeath.toIso8601String().split('T').first,
      'p_place_of_death': placeOfDeath,
      'p_cause_code': causeCode,
    });
  }

  /// SARS tax returns are keyed by `tax_number`, not the citizen's ID
  /// number directly -- resolved via `sars_taxpayers` first.
  Future<List<Map<String, dynamic>>> getSarsTaxReturnsForCitizen(String idNumber) async {
    final taxpayer = await _client
        .from('sars_taxpayers')
        .select('tax_number')
        .eq('national_id_number', idNumber)
        .maybeSingle();
    final taxNumber = taxpayer?['tax_number'] as String?;
    if (taxNumber == null) return [];
    return _client.from('sars_tax_returns').select().eq('tax_number', taxNumber).order('tax_year', ascending: false);
  }

  Future<DepartmentDashboardStats> getDashboardStats() async {
    final row = await _officialRow();
    final department = row['departments'] as Map<String, dynamic>?;
    final departmentId = department?['department_id'] as String?;
    final departmentName = department?['department_name'] as String? ?? 'Department';
    final category = DepartmentCategory.fromName(departmentName);

    if (departmentId == null) {
      return DepartmentDashboardStats(departmentName: departmentName, activeOfficials: 0);
    }

    // Only needed for _categoryStats' own per-category stats (e.g. "Credentials
    // issued" for DBE/DHET) -- verification is not a department concern any
    // more (organisations request it, an automated check decides it; a
    // department official never sees or acts on it -- see
    // docs/DECISIONS.md).
    final credentialTypeIds = await _client
        .from('credential_types')
        .select('credential_type_id')
        .eq('issuing_department_id', departmentId);
    final typeIds = [for (final r in credentialTypeIds) r['credential_type_id'] as String];

    final activeOfficials = await _client
        .from('department_officials')
        .count(CountOption.exact)
        .eq('department_id', departmentId)
        .eq('active', true);

    final departmentCode = department?['department_code'] as String? ?? '';
    final (categoryStats, recordsByService) = await (
      _categoryStats(category: category, departmentId: departmentId, typeIds: typeIds),
      _recordsByService(departmentCode),
    ).wait;

    return DepartmentDashboardStats(
      departmentName: departmentName,
      activeOfficials: activeOfficials,
      categoryStats: categoryStats,
      recordsByService: recordsByService,
    );
  }

  /// One exact row count per record type in [recordTypesForDepartment] --
  /// every one of those tables is owned by this department, so the count
  /// is that department's own record volume, subject to the same RLS as the
  /// record screens. A table that errors (no read access) is skipped rather
  /// than reported as 0.
  Future<List<(String, int)>> _recordsByService(String departmentCode) async {
    final types = recordTypesForDepartment(departmentCode).where((t) => t.table != null).toList();
    final counts = await Future.wait([
      for (final type in types)
        _client.from(type.table!).count(CountOption.exact).then<int?>((c) => c).catchError((Object _) => null),
    ]);
    return [
      for (var i = 0; i < types.length; i++)
        if (counts[i] != null) (types[i].label, counts[i]!),
    ];
  }

  /// Department-category-specific extra stats (spec: "do not make every
  /// department dashboard identical"). One screen, data-driven extra cards
  /// per category, rather than a per-department screen variant.
  Future<List<DepartmentStatItem>> _categoryStats({
    required DepartmentCategory category,
    required String departmentId,
    required List<String> typeIds,
  }) async {
    switch (category) {
      case DepartmentCategory.homeAffairs:
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
        final results = await Future.wait([
          _client.from('citizens').count(CountOption.exact),
          _client.from('citizens').count(CountOption.exact).eq('current_status', 'active'),
          _client.from('citizens').count(CountOption.exact).gte('registered_at', thirtyDaysAgo),
        ]);
        return [
          DepartmentStatItem(label: 'Total citizens', value: results[0], icon: Icons.groups_outlined),
          DepartmentStatItem(label: 'Active citizens', value: results[1], icon: Icons.verified_user_outlined),
          DepartmentStatItem(
            label: 'Registered (30 days)',
            value: results[2],
            icon: Icons.person_add_alt_outlined,
          ),
        ];

      case DepartmentCategory.sassa:
        final results = await Future.wait([
          _client.from('sassa_grants').count(CountOption.exact),
          _client.from('sassa_grants').count(CountOption.exact).eq('status', 'Active'),
        ]);
        return [
          DepartmentStatItem(label: 'Citizens with grants', value: results[0], icon: Icons.groups_outlined),
          DepartmentStatItem(label: 'Active grants', value: results[1], icon: Icons.volunteer_activism_outlined),
        ];

      case DepartmentCategory.basicEducation:
      case DepartmentCategory.higherEducation:
        if (typeIds.isEmpty) {
          return const [
            DepartmentStatItem(label: 'Credentials issued', value: 0, icon: Icons.school_outlined),
          ];
        }
        final credentialCount = await _client
            .from('credentials')
            .count(CountOption.exact)
            .inFilter('credential_type_id', typeIds);
        return [
          DepartmentStatItem(label: 'Credentials issued', value: credentialCount, icon: Icons.school_outlined),
        ];

      case DepartmentCategory.saps:
        final clearanceCount = await _client.from('saps_clearance_certificates').count(CountOption.exact);
        return [
          DepartmentStatItem(label: 'Clearance records', value: clearanceCount, icon: Icons.fingerprint_outlined),
        ];

      case DepartmentCategory.humanSettlements:
        final results = await Future.wait([
          _client.from('properties').count(CountOption.exact),
          // 'pending' is not a valid application_status (confirmed live via
          // housing_application_status_check); 'submitted'/'under_review'
          // are the real awaiting-decision states.
          _client.from('housing_applications').count(CountOption.exact).inFilter(
            'application_status',
            ['submitted', 'under_review'],
          ),
          _client.from('title_deeds').count(CountOption.exact).eq('registration_status', 'registered'),
        ]);
        return [
          DepartmentStatItem(label: 'Properties', value: results[0], icon: Icons.home_work_outlined),
          DepartmentStatItem(label: 'Pending applications', value: results[1], icon: Icons.assignment_outlined),
          DepartmentStatItem(label: 'Title deeds registered', value: results[2], icon: Icons.description_outlined),
        ];

      case DepartmentCategory.other:
        return const [];
    }
  }

  /// Home Affairs only -- gated by the live `citizens_insert` RLS policy
  /// (`is_official() AND current_official_department_code() =
  /// 'HOME_AFFAIRS'`), confirmed working end-to-end. Uses only `citizens`
  /// columns already confirmed in docs/SCREEN_DATABASE_MAP.md; no field is
  /// invented.
  ///
  /// [email] is required and must be the citizen's own, real address: it's
  /// how they later claim this record by signing up (`claim_citizen_account`
  /// matches on it, case-insensitively), so a made-up address would leave
  /// them unable to ever log in. Refused if another citizen already has it,
  /// since the claim couldn't tell the two records apart.
  Future<void> registerCitizen({
    required String idNumber,
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String email,
    String? phoneNumber,
  }) async {
    final normalisedEmail = email.trim().toLowerCase();
    final existing = await _client
        .from('citizens')
        .select('citizen_id')
        // Escape LIKE wildcards -- `_` is common in real addresses.
        .ilike('email', normalisedEmail.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}'))
        .limit(1);
    if (existing.isNotEmpty) {
      throw const AppException('Another citizen is already registered with this email address.');
    }

    await _client.from('citizens').insert({
      'id_number': idNumber,
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'current_status': 'active',
      if (phoneNumber != null && phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
      'email': normalisedEmail,
    });
  }

  /// SAPS-only. Looks a citizen up by ID number, then their most recent
  /// `saps_clearance_certificates` row via `national_id_number`.
  Future<ClearanceSearchResult?> searchCitizenForClearance(String idNumber) async {
    final citizenRow = await _client
        .from('citizens')
        .select('citizen_id, first_name, last_name, id_number, current_status')
        .eq('id_number', idNumber)
        .maybeSingle();
    if (citizenRow == null) return null;

    final clearanceRows = await _client
        .from('saps_clearance_certificates')
        .select('status, issue_date')
        .eq('national_id_number', citizenRow['id_number'] as String)
        .order('issue_date', ascending: false)
        .limit(1);
    final clearanceRow = clearanceRows.isEmpty ? null : clearanceRows.first;

    return ClearanceSearchResult(
      citizenId: citizenRow['citizen_id'] as String,
      fullName: '${citizenRow['first_name'] ?? ''} ${citizenRow['last_name'] ?? ''}'.trim(),
      idNumber: citizenRow['id_number'] as String? ?? idNumber,
      currentStatus: citizenRow['current_status'] as String? ?? 'unknown',
      clearanceStatus: clearanceRow?['status'] as String?,
      hasClearanceRecord: clearanceRow != null,
    );
  }

  /// Generic "search citizen by ID number" available to every department
  /// official (spec §3.2 step 1-2: "search for a citizen using their SA ID
  /// number, locate the citizen's central identity record"). Gated by the
  /// live `citizens_select` RLS policy, which already grants any active
  /// official read access to any citizen row -- this was previously only
  /// wired up for Home Affairs (registration) and SAPS (clearance search).
  Future<CitizenLookupResult?> searchCitizenByIdNumber(String idNumber) async {
    final row = await _client
        .from('citizens')
        .select('citizen_id, first_name, last_name, id_number, date_of_birth, current_status, phone_number, email')
        .eq('id_number', idNumber)
        .maybeSingle();
    if (row == null) return null;
    final dob = row['date_of_birth'] as String?;
    return CitizenLookupResult(
      citizenId: row['citizen_id'] as String,
      firstName: row['first_name'] as String? ?? '',
      lastName: row['last_name'] as String? ?? '',
      idNumber: row['id_number'] as String? ?? idNumber,
      currentStatus: row['current_status'] as String? ?? 'unknown',
      dateOfBirth: dob == null ? null : DateTime.tryParse(dob),
      phoneNumber: row['phone_number'] as String?,
      email: row['email'] as String?,
    );
  }

  /// Search by any combination of first name, last name and/or ID number
  /// (partial, case-insensitive on the names) -- returns a result list an
  /// official picks from, rather than requiring the exact ID up front like
  /// [searchCitizenByIdNumber]. Passing no filters at all (every argument
  /// null/empty) browses the first 50 citizens ordered by surname -- the
  /// "view all" case. Same `citizens_select` RLS as [searchCitizenByIdNumber]
  /// -- department officials and admins already have full-table read access
  /// to citizen identity rows, this only changes how they filter it.
  Future<List<CitizenLookupResult>> searchCitizens({
    String? idNumber,
    String? firstName,
    String? lastName,
  }) async {
    var query = _client
        .from('citizens')
        .select('citizen_id, first_name, last_name, id_number, date_of_birth, current_status, phone_number, email');
    if (idNumber != null && idNumber.trim().isNotEmpty) {
      query = query.eq('id_number', idNumber.trim());
    }
    if (firstName != null && firstName.trim().isNotEmpty) {
      query = query.ilike('first_name', '%${firstName.trim()}%');
    }
    if (lastName != null && lastName.trim().isNotEmpty) {
      query = query.ilike('last_name', '%${lastName.trim()}%');
    }
    final rows = await query.order('last_name').limit(50);
    return [
      for (final row in rows)
        CitizenLookupResult(
          citizenId: row['citizen_id'] as String,
          firstName: row['first_name'] as String? ?? '',
          lastName: row['last_name'] as String? ?? '',
          idNumber: row['id_number'] as String? ?? '',
          currentStatus: row['current_status'] as String? ?? 'unknown',
          dateOfBirth: (row['date_of_birth'] as String?) == null ? null : DateTime.tryParse(row['date_of_birth'] as String),
          phoneNumber: row['phone_number'] as String?,
          email: row['email'] as String?,
        ),
    ];
  }

  /// Lodges an appeal on a citizen's behalf against an existing record in
  /// this official's own department -- the citizen visits in person and
  /// disputes something (a suspended licence, a declined grant, etc.); an
  /// administrator (not another official) later reviews and decides it via
  /// `admin_decide_appeal` (docs/database/appeals_workflow.sql).
  Future<void> lodgeAppeal({
    required String citizenId,
    required String relatedTable,
    required String relatedId,
    required String appealReason,
  }) {
    return _client.rpc('lodge_appeal', params: {
      'p_citizen_id': citizenId,
      'p_related_table': relatedTable,
      'p_related_id': relatedId,
      'p_appeal_reason': appealReason,
    });
  }

  /// Fellow officials in the caller's own department -- requires
  /// `department_officials_select_colleagues` (an official can only see
  /// their own row otherwise, which also meant the "Officials" dashboard
  /// stat above was undercounted for every non-admin official before this
  /// policy existed).
  Future<List<ColleagueItem>> getColleagues() async {
    final row = await _officialRow();
    final departmentId = row['department_id'] as String?;
    if (departmentId == null) return [];

    final rows = await _client
        .from('department_officials')
        .select('official_id, full_name, official_role, active')
        .eq('department_id', departmentId)
        .order('full_name');

    return [
      for (final r in rows)
        ColleagueItem(
          officialId: r['official_id'] as String,
          fullName: r['full_name'] as String? ?? '',
          officialRole: r['official_role'] as String? ?? '',
          active: r['active'] as bool? ?? true,
        ),
    ];
  }

  /// Self-service staff creation for a Departmental Head/Admin, via the
  /// `dept_admin_create_staff` RPC -- always creates a `Staff`-tier
  /// account in the caller's own department; re-checked server-side, a
  /// plain Staff official calling this gets a clean rejection.
  Future<Map<String, dynamic>> createStaffMember({
    required String firstName,
    required String lastName,
    required String password,
    String? email,
  }) async {
    final result = await _client.rpc('dept_admin_create_staff', params: {
      'p_first_name': firstName,
      'p_last_name': lastName,
      'p_password': password,
      if (email != null && email.isNotEmpty) 'p_email': email,
    }) as Map<String, dynamic>;
    return result;
  }

  Future<void> setOfficialActive(String officialId, bool active) {
    return _client.rpc('dept_admin_set_official_active', params: {
      'p_official_id': officialId,
      'p_active': active,
    });
  }

  /// Built directly from [recordTypesForDepartment] -- one tile per actual
  /// record type this department manages (Marriage, Death, Passport,
  /// Immigration for Home Affairs; Driver's Licence, Vehicle for
  /// Transport; etc.), plus a handful of dedicated department-wide screens
  /// that don't fit the generic "pick a citizen first" shape. Previously
  /// derived from `credential_types` instead, which meant most departments
  /// (only one verifiable credential type each) showed a single generic
  /// tile no matter how many record types they actually managed -- see
  /// docs/KNOWN_LIMITATIONS.md.
  Future<List<DepartmentServiceItem>> getServices() async {
    final profile = await getProfile();
    final recordTypes = recordTypesForDepartment(profile.departmentCode);

    return [
      for (final type in recordTypes)
        DepartmentServiceItem(
          name: type.label,
          description: 'Search a citizen and manage their ${type.label.toLowerCase()} record.',
          icon: recordTypeIconByName[type.icon] ?? Icons.folder_outlined,
        ),
      ..._specialServicesFor(profile.departmentCode),
    ];
  }

  static List<DepartmentServiceItem> _specialServicesFor(String departmentCode) => switch (departmentCode) {
        'HOME_AFFAIRS' => const [
            DepartmentServiceItem(
              name: 'Register a new citizen',
              description: "Create a citizen's central identity record.",
              icon: Icons.person_add_alt_outlined,
              route: AppRoutes.departmentRegisterCitizen,
            ),
          ],
        'SAPS' => const [
            DepartmentServiceItem(
              name: 'Clearance search',
              description: 'Search a citizen for their criminal-clearance status.',
              icon: Icons.fingerprint_outlined,
              route: AppRoutes.departmentClearanceSearch,
            ),
            DepartmentServiceItem(
              name: 'Wanted list',
              description: 'Department-wide list of wanted persons.',
              icon: Icons.person_search_outlined,
              route: AppRoutes.departmentSapsWanted,
            ),
            DepartmentServiceItem(
              name: 'Offenders',
              description: 'Department-wide list of offenders on record.',
              icon: Icons.gavel_outlined,
              route: AppRoutes.departmentSapsOffenders,
            ),
          ],
        _ => const [],
      };
}

class DepartmentOfficialProfile {
  const DepartmentOfficialProfile({
    required this.fullName,
    required this.officialRole,
    required this.active,
    required this.departmentId,
    required this.departmentName,
    required this.departmentCode,
    required this.category,
    this.departmentCategory,
  });

  final String fullName;
  final String officialRole;
  final bool active;
  final String departmentId;
  final String departmentName;

  /// e.g. `HOME_AFFAIRS`, `TRANSPORT`, `SARS` -- keys into
  /// `recordTypesForDepartment` in `department_record_config.dart`.
  final String departmentCode;
  final String? departmentCategory;

  /// Classified from [departmentName] -- see DepartmentCategory.fromName.
  final DepartmentCategory category;
}

class ClearanceSearchResult {
  const ClearanceSearchResult({
    required this.citizenId,
    required this.fullName,
    required this.idNumber,
    required this.currentStatus,
    required this.hasClearanceRecord,
    this.clearanceStatus,
  });

  final String citizenId;
  final String fullName;
  final String idNumber;
  final String currentStatus;
  final bool hasClearanceRecord;
  final String? clearanceStatus;
}

class DepartmentServiceItem {
  const DepartmentServiceItem({required this.name, required this.description, required this.icon, this.route});

  final String name;
  final String description;
  final IconData icon;

  /// Null means "search a citizen, then manage this record type" (the
  /// generic `departmentCitizenRecords` flow) -- set only for the handful
  /// of department-wide or dedicated screens (Register a new citizen,
  /// SAPS Wanted List/Offenders/Clearance search) that aren't "pick a
  /// citizen first".
  final String? route;
}

class ColleagueItem {
  const ColleagueItem({
    required this.officialId,
    required this.fullName,
    required this.officialRole,
    required this.active,
  });

  final String officialId;
  final String fullName;
  final String officialRole;
  final bool active;
}

/// One row on the SAPS "Wanted List" screen -- backed by
/// `saps_wanted_persons`, a department-wide list rather than a per-citizen
/// record (see docs/database/saps_wanted_persons.sql).
class WantedPersonItem {
  const WantedPersonItem({
    required this.wantedId,
    required this.idNumber,
    required this.fullName,
    required this.reason,
    required this.dateListed,
    required this.status,
  });

  final String wantedId;
  final String idNumber;
  final String fullName;
  final String reason;
  final DateTime dateListed;

  /// 'Wanted' | 'Apprehended' | 'Cleared'.
  final String status;
}

/// One row on the SAPS "Offenders" screen -- a department-wide view over
/// the existing `saps_criminal_records` table (no new table needed).
class OffenderItem {
  const OffenderItem({
    required this.caseNumber,
    required this.idNumber,
    required this.fullName,
    required this.offenceCode,
    required this.convictionDate,
    required this.sentenceStatus,
  });

  final String caseNumber;
  final String idNumber;
  final String fullName;
  final String offenceCode;
  final DateTime convictionDate;
  final String sentenceStatus;
}

final departmentRepositoryProvider = Provider<DepartmentRepository>((ref) {
  ref.watch(authStateChangesProvider);
  return DepartmentRepository(ref.watch(supabaseClientProvider));
});

final wantedPersonsProvider = FutureProvider.autoDispose<List<WantedPersonItem>>((ref) {
  return ref.watch(departmentRepositoryProvider).getWantedPersons();
});

final offendersProvider = FutureProvider.autoDispose<List<OffenderItem>>((ref) {
  return ref.watch(departmentRepositoryProvider).getOffenders();
});

final departmentProfileProvider = FutureProvider.autoDispose<DepartmentOfficialProfile>((ref) {
  return ref.watch(departmentRepositoryProvider).getProfile();
});

final departmentDashboardStatsProvider = FutureProvider.autoDispose<DepartmentDashboardStats>((ref) {
  return ref.watch(departmentRepositoryProvider).getDashboardStats();
});

final departmentServicesProvider = FutureProvider.autoDispose<List<DepartmentServiceItem>>((ref) {
  return ref.watch(departmentRepositoryProvider).getServices();
});

final clearanceSearchProvider =
    FutureProvider.autoDispose.family<ClearanceSearchResult?, String>((ref, idNumber) {
  return ref.watch(departmentRepositoryProvider).searchCitizenForClearance(idNumber);
});

final departmentColleaguesProvider = FutureProvider.autoDispose<List<ColleagueItem>>((ref) {
  return ref.watch(departmentRepositoryProvider).getColleagues();
});
