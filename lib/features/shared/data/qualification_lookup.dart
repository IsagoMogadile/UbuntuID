import 'package:supabase_flutter/supabase_flutter.dart';

import '../../citizen/domain/credential_item.dart';

/// Resolves the real record behind an NSC/TERTIARY_QUALIFICATION credential
/// -- pulled from `dbe_nsc_results` or `dhet_academic_records` (embedding
/// `dhet_institutions` for the actual institution name, not just its code)
/// -- so both a citizen viewing their own credentials and an organisation
/// verifying someone else's see the qualification itself, not just a
/// generic "active" badge. `null` for every other credential type, or when
/// no matching row exists yet.
///
/// Shared between `CitizenRepository` and `OrganisationRepository` -- same
/// query either way, just gated by different RLS policies for who's asking
/// (citizen: their own row; organisation: scoped by
/// `organisation_credential_scopes`, same as every other verification read).
Future<QualificationDetail?> fetchQualificationDetail(
  SupabaseClient client, {
  required String? typeCode,
  required String nationalIdNumber,
}) async {
  switch (typeCode) {
    case 'NSC':
      final row = await client
          .from('dbe_nsc_results')
          .select('year, overall_pass_status')
          .eq('national_id_number', nationalIdNumber)
          .order('year', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return QualificationDetail(
        qualificationName: 'National Senior Certificate (Matric)',
        result: row['overall_pass_status'] as String?,
        year: row['year'] as int?,
      );

    case 'TERTIARY_QUALIFICATION':
      // A completed academic record (with an actual result) is more
      // authoritative than an in-progress enrolment -- prefer it, fall
      // back to the enrolment if the citizen hasn't completed anything yet.
      final academic = await client
          .from('dhet_academic_records')
          .select('qualification_name, year, final_result, dhet_institutions(institution_name)')
          .eq('national_id_number', nationalIdNumber)
          .order('year', ascending: false)
          .limit(1)
          .maybeSingle();
      if (academic != null) {
        return QualificationDetail(
          qualificationName: academic['qualification_name'] as String? ?? 'Qualification',
          institutionName: academic['dhet_institutions']?['institution_name'] as String?,
          result: academic['final_result'] as String?,
          year: academic['year'] as int?,
        );
      }

      final enrolment = await client
          .from('dhet_student_enrollment')
          .select('qualification_name, completion_status, dhet_institutions(institution_name)')
          .eq('national_id_number', nationalIdNumber)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (enrolment == null) return null;
      return QualificationDetail(
        qualificationName: enrolment['qualification_name'] as String? ?? 'Qualification',
        institutionName: enrolment['dhet_institutions']?['institution_name'] as String?,
        result: enrolment['completion_status'] as String?,
      );

    default:
      return null;
  }
}
