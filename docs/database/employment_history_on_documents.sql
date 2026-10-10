-- employment_history_on_documents
--
-- The Employment & UIF document (download and QR scan) showed only the
-- single latest labour_employment_records row. A citizen can hold several
-- jobs at once and has past jobs, so public_document now adds the full
-- history to the LABOUR_STATUS record as `history` (open rows first, then
-- newest start date). The letter lists current jobs and past jobs from it.
--
-- APPLIED 2026-10-10 via the Supabase MCP.

create or replace function public.public_document(p_ref uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_cred      credentials%rowtype;
  v_type      credential_types%rowtype;
  v_citizen   citizens%rowtype;
  v_kind      text;
  v_dept      text;
  v_record    jsonb;
  v_qual      jsonb;
  v_address   jsonb;
begin
  select * into v_cred from credentials where credential_id = p_ref;

  if found then
    v_kind := 'credential';
    select * into v_type from credential_types where credential_type_id = v_cred.credential_type_id;
    select department_name into v_dept
      from departments
      where department_id = coalesce(v_cred.issuing_department_id, v_type.issuing_department_id);
    select * into v_citizen from citizens where citizen_id = v_cred.citizen_id;
  else
    select * into v_citizen from citizens where citizen_id = p_ref;
    if not found then
      return null;
    end if;
    v_kind := 'identity';
    -- Only the ID document prints an address (on its reverse).
    select to_jsonb(a) into v_address
      from citizen_addresses a
      where a.citizen_id = v_citizen.citizen_id
      order by a.is_current desc, a.effective_date desc
      limit 1;
  end if;

  if v_kind = 'credential' then
    -- The department record behind the credential: latest row per type,
    -- same tables and ordering as getCredentialRecord().
    v_record := case v_type.type_code
      when 'PASSPORT' then (select to_jsonb(r) from dha_passports r
        where r.national_id_number = v_citizen.id_number order by r.issue_date desc limit 1)
      when 'DRIVERS_LICENCE' then (select to_jsonb(r) from dot_driver_licences r
        where r.national_id_number = v_citizen.id_number order by r.issue_date desc limit 1)
      when 'TAX_COMPLIANCE' then (select to_jsonb(r) from sars_taxpayers r
        where r.national_id_number = v_citizen.id_number order by r.registered_date desc limit 1)
      when 'CRIMINAL_CLEARANCE' then (select to_jsonb(r) from saps_clearance_certificates r
        where r.national_id_number = v_citizen.id_number order by r.issue_date desc limit 1)
      when 'NSC' then (select to_jsonb(r) from dbe_nsc_results r
        where r.national_id_number = v_citizen.id_number order by r.year desc limit 1)
      -- Employment carries the whole history too: someone can hold more
      -- than one job at once, and past jobs belong on the letter.
      when 'LABOUR_STATUS' then (select to_jsonb(r) || jsonb_build_object('history', (
          select coalesce(jsonb_agg(to_jsonb(h) order by (h.end_date is null) desc, h.start_date desc), '[]'::jsonb)
          from labour_employment_records h
          where h.national_id_number = v_citizen.id_number))
        from labour_employment_records r
        where r.national_id_number = v_citizen.id_number order by r.start_date desc limit 1)
      when 'SASSA_STATUS' then (select to_jsonb(r) from sassa_grants r
        where r.national_id_number = v_citizen.id_number order by r.created_at desc limit 1)
      else null
    end;

    -- Same as fetchQualificationDetail(): matric result, or the latest
    -- completed tertiary record, falling back to the latest enrolment.
    if v_type.type_code = 'NSC' then
      select jsonb_build_object(
          'qualification_name', 'National Senior Certificate (Matric)',
          'result', r.overall_pass_status,
          'year', r.year)
        into v_qual
        from dbe_nsc_results r
        where r.national_id_number = v_citizen.id_number
        order by r.year desc limit 1;
    elsif v_type.type_code = 'TERTIARY_QUALIFICATION' then
      select jsonb_build_object(
          'qualification_name', coalesce(r.qualification_name, 'Qualification'),
          'institution_name', i.institution_name,
          'result', r.final_result,
          'year', r.year)
        into v_qual
        from dhet_academic_records r
        left join dhet_institutions i on i.institution_code = r.institution_code
        where r.national_id_number = v_citizen.id_number
        order by r.year desc limit 1;
      if v_qual is null then
        select jsonb_build_object(
            'qualification_name', coalesce(r.qualification_name, 'Qualification'),
            'institution_name', i.institution_name,
            'result', r.completion_status)
          into v_qual
          from dhet_student_enrollment r
          left join dhet_institutions i on i.institution_code = r.institution_code
          where r.national_id_number = v_citizen.id_number
          order by r.created_at desc limit 1;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'kind', v_kind,
    'holder', jsonb_build_object(
      'citizen_id',         v_citizen.citizen_id,
      'id_number',          v_citizen.id_number,
      'first_name',         v_citizen.first_name,
      'last_name',          v_citizen.last_name,
      'date_of_birth',      v_citizen.date_of_birth,
      'gender',             v_citizen.gender,
      'citizenship_status', v_citizen.citizenship_status,
      'current_status',     v_citizen.current_status,
      'registered_at',      v_citizen.registered_at
    ),
    'address', v_address,
    'credential', case when v_kind = 'credential' then jsonb_build_object(
      'credential_id', v_cred.credential_id,
      'type_code',     v_type.type_code,
      'display_name',  v_type.display_name,
      'department',    v_dept,
      'status',        v_cred.status,
      'issued_date',   v_cred.issued_date,
      'expiry_date',   v_cred.expiry_date
    ) end,
    'record', v_record,
    'qualification', v_qual
  );
end;
$$;
