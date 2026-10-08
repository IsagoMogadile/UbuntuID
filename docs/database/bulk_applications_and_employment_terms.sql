-- bulk_applications_and_employment_terms
--
-- 1. org_submit_application: one call creates a whole application (consent
--    grant + verification request + one result row per credential, with
--    the organisation's claimed values). Used by both the single "New
--    Applicant" flow and the new bulk Excel/CSV upload, so 500 applicants
--    cost 500 calls instead of 1,500 and each application is atomic.
--
--    Same person applies twice -> the new application replaces the old:
--    this organisation's earlier requests for the citizen are set to
--    'cancelled' (hidden from the Applicants list, kept for the audit
--    trail) rather than deleted.
--
--    Credentials are limited to the organisation's approved scopes
--    (organisation_credential_scopes, chosen at registration) -- enforced
--    here, not just filtered in the app.
--
-- 2. Employment terms: organisation_employees gains employment_type and
--    end_date (required for anything other than Permanent), set through
--    offer_employment_with_terms, which wraps the existing
--    offer_employment (docs/database/offer_employment_records_with_labour.sql).
--    Any organisation staff member may offer employment, as before.

-- ---------------------------------------------------------------------
-- 1. Applications
-- ---------------------------------------------------------------------

create or replace function public.org_submit_application(
  p_citizen_id uuid,
  p_credential_type_ids uuid[],
  p_claims jsonb default '{}'::jsonb   -- { "<credential_type_id>": { field: value, ... } }
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid := current_org_user_organisation_id();
  v_user_id uuid;
  v_consent_id uuid;
  v_request_id uuid;
  v_replaced int := 0;
  v_type_id uuid;
begin
  if v_org_id is null then
    raise exception 'Only an approved organisation user may submit applications.';
  end if;
  if p_credential_type_ids is null or cardinality(p_credential_type_ids) = 0 then
    raise exception 'Select at least one credential to check.';
  end if;
  if not exists (select 1 from citizens where citizen_id = p_citizen_id) then
    raise exception 'Citizen not found.';
  end if;

  foreach v_type_id in array p_credential_type_ids loop
    if not exists (
      select 1 from organisation_credential_scopes
      where organisation_id = v_org_id and credential_type_id = v_type_id
    ) then
      raise exception 'Your organisation is not approved to verify one of the selected credentials.';
    end if;
  end loop;

  select organisation_user_id into v_user_id from organisation_users where auth_user_id = auth.uid();

  update verification_requests
     set overall_status = 'cancelled'
   where organisation_id = v_org_id
     and citizen_id = p_citizen_id
     and overall_status <> 'cancelled';
  get diagnostics v_replaced = row_count;

  insert into consent_grants (citizen_id, organisation_id, scope)
  values (p_citizen_id, v_org_id, jsonb_build_object('credential_type_ids', to_jsonb(p_credential_type_ids)))
  returning consent_id into v_consent_id;

  insert into verification_requests (
    citizen_id, organisation_id, requested_by_user_id, consent_id, overall_status, requested_at
  )
  values (p_citizen_id, v_org_id, v_user_id, v_consent_id, 'pending', now())
  returning request_id into v_request_id;

  insert into verification_results (request_id, credential_type_id, match_status, claimed_value)
  select v_request_id, t.type_id, 'pending', p_claims -> t.type_id::text
  from unnest(p_credential_type_ids) as t(type_id);

  if v_replaced > 0 then
    insert into audit_logs (action, actor_id, actor_type, related_id, related_table, target_citizen_id, metadata)
    values ('application_replaced', v_user_id, 'organisation_user', v_request_id, 'verification_requests',
            p_citizen_id, jsonb_build_object('replaced_requests', v_replaced));
  end if;

  return jsonb_build_object('request_id', v_request_id, 'replaced', v_replaced);
end;
$$;

revoke all on function public.org_submit_application(uuid, uuid[], jsonb) from public, anon;
grant execute on function public.org_submit_application(uuid, uuid[], jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 2. Employment terms
-- ---------------------------------------------------------------------

alter table public.organisation_employees
  add column if not exists employment_type text not null default 'Permanent',
  add column if not exists end_date date;

alter table public.organisation_employees
  drop constraint if exists organisation_employees_employment_type_check;
alter table public.organisation_employees
  add constraint organisation_employees_employment_type_check
  check (employment_type in ('Permanent', 'Fixed-term contract', 'Temporary', 'Internship'));

alter table public.organisation_employees
  drop constraint if exists organisation_employees_end_date_check;
alter table public.organisation_employees
  add constraint organisation_employees_end_date_check
  check (
    (employment_type = 'Permanent' and end_date is null)
    or (employment_type <> 'Permanent' and end_date is not null and end_date >= start_date)
  );

create or replace function public.offer_employment_with_terms(
  p_citizen_id uuid,
  p_job_title text,
  p_department_or_position text,
  p_salary numeric,
  p_salary_frequency text,
  p_start_date date,
  p_employment_type text,
  p_end_date date,
  p_source_verification_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if p_employment_type is null
     or p_employment_type not in ('Permanent', 'Fixed-term contract', 'Temporary', 'Internship') then
    raise exception 'Choose an employment type.';
  end if;
  if p_employment_type <> 'Permanent' and p_end_date is null then
    raise exception 'An end date is required for a % position.', lower(p_employment_type);
  end if;
  if p_end_date is not null and p_end_date < p_start_date then
    raise exception 'The end date cannot be before the start date.';
  end if;

  v_result := offer_employment(
    p_citizen_id, p_job_title, p_department_or_position, p_salary,
    p_salary_frequency, p_start_date, p_source_verification_request_id
  );

  update organisation_employees
     set employment_type = p_employment_type,
         end_date = case when p_employment_type = 'Permanent' then null else p_end_date end
   where employee_id = (v_result ->> 'employee_id')::uuid;

  return v_result;
end;
$$;

revoke all on function public.offer_employment_with_terms(uuid, text, text, numeric, text, date, text, date, uuid)
  from public, anon;
grant execute on function public.offer_employment_with_terms(uuid, text, text, numeric, text, date, text, date, uuid)
  to authenticated;
