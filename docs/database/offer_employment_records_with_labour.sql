-- offer_employment_records_with_labour
--
-- Closes the loop the user pointed out: "department of labour records
-- this, and citizen is now working" -- when an organisation offers
-- employment, that's not just the organisation's own private HR note any
-- more; Employment and Labour's own official record
-- (`labour_employment_records`) reflects it too, automatically, the same
-- way every other cross-department fact in this app updates without a
-- human re-typing it (the credentials-mirror convention -- see
-- docs/DATA_MODEL.md's "Credentials" section). This is a genuine
-- department "doing its own job" (Labour already owns Employment/UIF
-- records) triggered by a real-world event, not the verification pattern
-- that was explicitly removed from departments this session -- see
-- docs/DECISIONS.md, which draws that line directly.
--
-- Replaces `OrganisationRepository.offerEmployment`'s previous plain
-- `organisation_employees` insert with this RPC. Two things happen inside
-- one call: the organisation's own HR row is created (always succeeds --
-- it's their own internal record), and Labour's official record is
-- created/updated to 'Employed' -- *unless* the citizen is currently
-- enrolled full-time, the same rule `record_employment` already enforces
-- for an official doing this by hand (docs/database/
-- cross_department_eligibility_checks.sql). In that case the organisation
-- still gets its own HR row, just with a clear note that the government
-- record wasn't touched, rather than the whole offer failing outright --
-- an org's internal note about a future hire shouldn't be blocked by a
-- government rule about *current* full-time study.
--
-- SECURITY DEFINER because an organisation has no RLS write access to
-- labour_employment_records (rightly so -- see below) or credentials;
-- this is the one narrow, audited path where a real-world employment
-- event is allowed to write Labour's table without a LABOUR official
-- typing it in by hand.
--
-- APPLIED 2026-09-10 via Supabase MCP.

create or replace function public.offer_employment(
  p_citizen_id uuid,
  p_job_title text,
  p_department_or_position text,
  p_salary numeric,
  p_salary_frequency text,
  p_start_date date,
  p_source_verification_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_org_name text;
  v_offered_by uuid;
  v_national_id text;
  v_employee_id uuid;
  v_enrolment_status text;
  v_study_mode text;
  v_labour_recorded boolean := false;
  v_skip_reason text;
  v_labour_type_id uuid;
  v_existing_credential_id uuid;
begin
  v_org_id := current_org_user_organisation_id();
  if v_org_id is null then
    raise exception 'Only an approved organisation user may offer employment.';
  end if;

  select id_number into v_national_id from citizens where citizen_id = p_citizen_id;
  if v_national_id is null then
    raise exception 'Citizen not found.';
  end if;

  select legal_name into v_org_name from organisations where organisation_id = v_org_id;
  select organisation_user_id into v_offered_by from organisation_users where auth_user_id = auth.uid();

  -- The organisation's own HR record -- always created, this is their own
  -- internal note about who they've hired, not a government record.
  insert into organisation_employees (
    citizen_id, organisation_id, offered_by_user_id, source_verification_request_id,
    job_title, department_or_position, salary, salary_frequency, start_date
  )
  values (
    p_citizen_id, v_org_id, v_offered_by, p_source_verification_request_id,
    p_job_title, p_department_or_position, p_salary, coalesce(p_salary_frequency, 'Monthly'), p_start_date
  )
  returning employee_id into v_employee_id;

  -- Employment and Labour's own official record -- skipped, not failed,
  -- if the citizen is currently enrolled full-time (same rule
  -- record_employment enforces for an official doing this by hand).
  select completion_status, study_mode into v_enrolment_status, v_study_mode
  from dhet_student_enrollment where national_id_number = v_national_id
  order by created_at desc limit 1;

  if v_enrolment_status = 'Enrolled' and v_study_mode = 'Full-time' then
    v_skip_reason := 'Citizen is currently enrolled full-time with Higher Education and Training -- '
      'Department of Labour''s official employment record was not updated.';
  else
    insert into labour_employment_records (
      national_id_number, employer_name, employment_status, start_date,
      uif_contribution_amount, uif_claim_status
    )
    values (v_national_id, coalesce(v_org_name, 'Unknown employer'), 'Employed', p_start_date, 0, 'Not Claiming');

    -- Mirror the LABOUR_STATUS credential, same find-or-create semantics
    -- as DepartmentRepository._updateCredentialMirror (most recent row
    -- for this citizen+type gets updated; only inserts if none exists).
    select credential_type_id into v_labour_type_id from credential_types where type_code = 'LABOUR_STATUS';

    select credential_id into v_existing_credential_id
    from credentials
    where citizen_id = p_citizen_id and credential_type_id = v_labour_type_id
    order by issued_date desc limit 1;

    if v_existing_credential_id is not null then
      update credentials set status = 'active' where credential_id = v_existing_credential_id;
    else
      insert into credentials (citizen_id, credential_type_id, issuing_department_id, status, issued_date)
      select p_citizen_id, credential_type_id, issuing_department_id, 'active', p_start_date
      from credential_types where type_code = 'LABOUR_STATUS';
    end if;

    v_labour_recorded := true;
  end if;

  -- Notification for the employment offer itself is already handled by
  -- the existing trg_notify_citizen_on_employment_offer trigger on
  -- organisation_employees -- not duplicated here.

  return jsonb_build_object(
    'employee_id', v_employee_id,
    'labour_recorded', v_labour_recorded,
    'skip_reason', v_skip_reason
  );
end;
$$;

grant execute on function public.offer_employment(uuid, text, text, numeric, text, date, uuid) to authenticated;
