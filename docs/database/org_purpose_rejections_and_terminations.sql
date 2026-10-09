-- org_purpose_rejections_and_terminations
--
-- 1. Why an organisation wants access: organisations.access_purpose plus a
--    reason per requested credential (organisation_credential_scopes.reason),
--    captured at registration / resubmission and shown to the admin who
--    approves it. The new parameters have defaults, so older app builds that
--    don't send them keep working.
--
-- 2. Rejecting an applicant: verification_requests gains a decision
--    (offered | rejected) with a reason. Rejecting notifies the citizen;
--    offering employment records 'offered' on the source request.
--
-- 3. Ending an employment: organisation_employees gains termination
--    details. org_end_employment sets the employee to Terminated, closes the
--    Department of Labour record the offer opened and notifies the citizen.
--
-- 4. Bulk upload feedback: org_notify_incomplete_application tells a
--    citizen their application was not considered because it was
--    incomplete, and why.

-- ---------------------------------------------------------------------
-- 1. Access purpose and per-credential reasons
-- ---------------------------------------------------------------------

alter table public.organisations add column if not exists access_purpose text;
alter table public.organisation_credential_scopes add column if not exists reason text;

drop function if exists public.register_organisation(text, text, text, text, text, text[], text, text, text, text);
create or replace function public.register_organisation(
  p_legal_name text,
  p_registration_number text,
  p_organisation_type text,
  p_contact_email text,
  p_contact_phone text,
  p_credential_type_codes text[],
  p_head_first_name text,
  p_head_last_name text,
  p_head_gender text,
  p_head_id_number text,
  p_access_purpose text default null,
  p_credential_reasons jsonb default '{}'::jsonb   -- { "<type_code>": "reason", ... }
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_org_id uuid;
  v_full_name text;
begin
  if v_uid is null then
    raise exception 'You must be signed in to register an organisation';
  end if;
  if exists (select 1 from organisation_users where auth_user_id = v_uid) then
    raise exception 'This account is already linked to an organisation';
  end if;
  if p_legal_name is null or trim(p_legal_name) = '' then
    raise exception 'Organisation legal name is required';
  end if;
  if p_credential_type_codes is null or array_length(p_credential_type_codes, 1) is null then
    raise exception 'Select at least one credential type your organisation needs to verify';
  end if;

  v_full_name := trim(concat_ws(' ', p_head_first_name, p_head_last_name));

  insert into organisations (
    legal_name, registration_number, organisation_type, access_tier, verified,
    contact_email, contact_phone, registration_status, requested_at, access_purpose
  ) values (
    p_legal_name, p_registration_number, p_organisation_type, 'basic', false,
    p_contact_email, p_contact_phone, 'pending', now(), nullif(trim(p_access_purpose), '')
  ) returning organisation_id into v_org_id;

  insert into organisation_users (
    auth_user_id, organisation_id, full_name, first_name, last_name, user_role, active, email, gender, id_number
  ) values (
    v_uid, v_org_id, v_full_name, p_head_first_name, p_head_last_name, 'manager', true, p_contact_email, p_head_gender, p_head_id_number
  );

  insert into organisation_credential_scopes (organisation_id, credential_type_id, reason)
  select v_org_id, credential_type_id, nullif(trim(coalesce(p_credential_reasons ->> type_code, '')), '')
  from credential_types where type_code = any(p_credential_type_codes);

  return v_org_id;
end;
$$;

drop function if exists public.resubmit_organisation(uuid, text, text, text, text, text, text[]);
create or replace function public.resubmit_organisation(
  p_organisation_id uuid,
  p_legal_name text,
  p_registration_number text,
  p_organisation_type text,
  p_contact_email text,
  p_contact_phone text,
  p_credential_type_codes text[],
  p_access_purpose text default null,
  p_credential_reasons jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from organisation_users
    where auth_user_id = auth.uid() and organisation_id = p_organisation_id and user_role = 'manager'
  ) then
    raise exception 'Only the organisation head can resubmit this application';
  end if;
  if not exists (select 1 from organisations where organisation_id = p_organisation_id and registration_status = 'declined') then
    raise exception 'Only a declined application can be resubmitted';
  end if;

  update organisations set
    legal_name = p_legal_name, registration_number = p_registration_number, organisation_type = p_organisation_type,
    contact_email = p_contact_email, contact_phone = p_contact_phone,
    access_purpose = coalesce(nullif(trim(p_access_purpose), ''), access_purpose),
    registration_status = 'pending', requested_at = now(), reviewed_by_admin_id = null, reviewed_at = null, decline_reason = null
  where organisation_id = p_organisation_id;

  delete from organisation_credential_scopes where organisation_id = p_organisation_id;
  insert into organisation_credential_scopes (organisation_id, credential_type_id, reason)
  select p_organisation_id, credential_type_id, nullif(trim(coalesce(p_credential_reasons ->> type_code, '')), '')
  from credential_types where type_code = any(p_credential_type_codes);
end;
$$;

revoke all on function public.register_organisation(text, text, text, text, text, text[], text, text, text, text, text, jsonb) from public, anon;
grant execute on function public.register_organisation(text, text, text, text, text, text[], text, text, text, text, text, jsonb) to authenticated;
revoke all on function public.resubmit_organisation(uuid, text, text, text, text, text, text[], text, jsonb) from public, anon;
grant execute on function public.resubmit_organisation(uuid, text, text, text, text, text, text[], text, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 2. Applicant decisions
-- ---------------------------------------------------------------------

alter table public.verification_requests
  add column if not exists decision text,
  add column if not exists decision_reason text,
  add column if not exists decided_at timestamptz,
  add column if not exists decided_by_user_id uuid references public.organisation_users (organisation_user_id);

alter table public.verification_requests drop constraint if exists verification_requests_decision_check;
alter table public.verification_requests
  add constraint verification_requests_decision_check check (decision is null or decision in ('offered', 'rejected'));

create or replace function public.org_reject_applicant(p_request_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid := current_org_user_organisation_id();
  v_user_id uuid;
  v_citizen_id uuid;
  v_org_name text;
begin
  if v_org_id is null then
    raise exception 'Only an approved organisation user may reject applicants.';
  end if;
  if p_reason is null or trim(p_reason) = '' then
    raise exception 'Give a reason for rejecting this applicant.';
  end if;

  select citizen_id into v_citizen_id
  from verification_requests
  where request_id = p_request_id and organisation_id = v_org_id and overall_status <> 'cancelled';
  if v_citizen_id is null then
    raise exception 'Application not found.';
  end if;
  if exists (select 1 from verification_requests where request_id = p_request_id and decision is not null) then
    raise exception 'A decision has already been made on this application.';
  end if;

  select organisation_user_id into v_user_id from organisation_users where auth_user_id = auth.uid();
  select legal_name into v_org_name from organisations where organisation_id = v_org_id;

  update verification_requests
     set decision = 'rejected', decision_reason = trim(p_reason), decided_at = now(), decided_by_user_id = v_user_id
   where request_id = p_request_id;

  insert into notifications (citizen_id, channel, message, delivery_status, sent_at)
  values (v_citizen_id, 'in_app',
          'Your application to ' || coalesce(v_org_name, 'an organisation') || ' was not successful. Reason: ' || trim(p_reason),
          'sent', now());

  insert into audit_logs (action, actor_id, actor_type, related_id, related_table, target_citizen_id, metadata)
  values ('applicant_rejected', v_user_id, 'organisation_user', p_request_id, 'verification_requests',
          v_citizen_id, jsonb_build_object('reason', trim(p_reason)));
end;
$$;

revoke all on function public.org_reject_applicant(uuid, text) from public, anon;
grant execute on function public.org_reject_applicant(uuid, text) to authenticated;

-- Offering employment records the decision on the source application.
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
  if p_source_verification_request_id is not null and exists (
    select 1 from verification_requests
    where request_id = p_source_verification_request_id and decision = 'rejected'
  ) then
    raise exception 'This applicant was rejected. Ask them to apply again before offering employment.';
  end if;

  v_result := offer_employment(
    p_citizen_id, p_job_title, p_department_or_position, p_salary,
    p_salary_frequency, p_start_date, p_source_verification_request_id
  );

  update organisation_employees
     set employment_type = p_employment_type,
         end_date = case when p_employment_type = 'Permanent' then null else p_end_date end
   where employee_id = (v_result ->> 'employee_id')::uuid;

  if p_source_verification_request_id is not null then
    update verification_requests
       set decision = 'offered', decided_at = now(),
           decided_by_user_id = (select organisation_user_id from organisation_users where auth_user_id = auth.uid())
     where request_id = p_source_verification_request_id
       and organisation_id = current_org_user_organisation_id();
  end if;

  return v_result;
end;
$$;

-- Backfill: applications that already led to an offer.
update verification_requests vr
   set decision = 'offered', decided_at = coalesce(vr.decided_at, e.created_at)
  from organisation_employees e
 where e.source_verification_request_id = vr.request_id and vr.decision is null;

-- ---------------------------------------------------------------------
-- 3. Ending an employment
-- ---------------------------------------------------------------------

alter table public.organisation_employees
  add column if not exists termination_reason text,
  add column if not exists terminated_at timestamptz;

-- A permanent post has no end date until it is ended.
alter table public.organisation_employees drop constraint if exists organisation_employees_end_date_check;
alter table public.organisation_employees
  add constraint organisation_employees_end_date_check
  check (
    ((employment_type = 'Permanent' and (end_date is null or employment_status = 'Terminated'))
     or (employment_type <> 'Permanent' and end_date is not null))
    and (end_date is null or end_date >= start_date)
  );

create or replace function public.org_end_employment(p_employee_id uuid, p_end_date date, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid := current_org_user_organisation_id();
  v_user_id uuid;
  v_emp organisation_employees%rowtype;
  v_org_name text;
  v_national_id text;
  v_labour_closed int := 0;
begin
  if v_org_id is null then
    raise exception 'Only an approved organisation user may end an employment.';
  end if;
  if p_reason is null or trim(p_reason) = '' then
    raise exception 'Give a reason for ending this employment.';
  end if;

  select * into v_emp from organisation_employees where employee_id = p_employee_id and organisation_id = v_org_id;
  if v_emp.employee_id is null then
    raise exception 'Employee not found.';
  end if;
  if v_emp.employment_status = 'Terminated' then
    raise exception 'This employment has already ended.';
  end if;
  if p_end_date is null or p_end_date < v_emp.start_date then
    raise exception 'The end date cannot be before the start date (%).', v_emp.start_date;
  end if;

  select organisation_user_id into v_user_id from organisation_users where auth_user_id = auth.uid();
  select legal_name into v_org_name from organisations where organisation_id = v_org_id;
  select id_number into v_national_id from citizens where citizen_id = v_emp.citizen_id;

  update organisation_employees
     set employment_status = 'Terminated', end_date = p_end_date,
         termination_reason = trim(p_reason), terminated_at = now()
   where employee_id = p_employee_id;

  -- Close the Labour record the offer opened (same employer, same start).
  update labour_employment_records
     set end_date = p_end_date, employment_status = 'Unemployed'
   where national_id_number = v_national_id
     and employer_name = v_org_name
     and start_date = v_emp.start_date
     and end_date is null;
  get diagnostics v_labour_closed = row_count;

  -- No other open employment left: the Labour credential is no longer current.
  if v_labour_closed > 0 and not exists (
    select 1 from labour_employment_records
    where national_id_number = v_national_id and end_date is null and employment_status in ('Employed', 'Self-Employed')
  ) then
    update credentials set status = 'suspended'
     where citizen_id = v_emp.citizen_id
       and credential_type_id = (select credential_type_id from credential_types where type_code = 'LABOUR_STATUS')
       and status = 'active';
  end if;

  insert into notifications (citizen_id, channel, message, delivery_status, sent_at)
  values (v_emp.citizen_id, 'in_app',
          'Your employment at ' || coalesce(v_org_name, 'an organisation') || ' as ' || v_emp.job_title
            || ' ends on ' || to_char(p_end_date, 'DD Mon YYYY') || '. Reason: ' || trim(p_reason),
          'sent', now());

  insert into audit_logs (action, actor_id, actor_type, related_id, related_table, target_citizen_id, metadata)
  values ('employment_ended', v_user_id, 'organisation_user', p_employee_id, 'organisation_employees',
          v_emp.citizen_id, jsonb_build_object('reason', trim(p_reason), 'end_date', p_end_date));

  return jsonb_build_object('labour_record_closed', v_labour_closed > 0);
end;
$$;

revoke all on function public.org_end_employment(uuid, date, text) from public, anon;
grant execute on function public.org_end_employment(uuid, date, text) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Bulk upload: incomplete application feedback
-- ---------------------------------------------------------------------

create or replace function public.org_notify_incomplete_application(p_citizen_id uuid, p_missing text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid := current_org_user_organisation_id();
  v_org_name text;
begin
  if v_org_id is null then
    raise exception 'Only an approved organisation user may send application feedback.';
  end if;
  if not exists (select 1 from citizens where citizen_id = p_citizen_id) then
    raise exception 'Citizen not found.';
  end if;

  select legal_name into v_org_name from organisations where organisation_id = v_org_id;

  insert into notifications (citizen_id, channel, message, delivery_status, sent_at)
  values (p_citizen_id, 'in_app',
          'Your application to ' || coalesce(v_org_name, 'an organisation')
            || ' was not considered because it was incomplete: ' || left(coalesce(nullif(trim(p_missing), ''), 'details were missing'), 400)
            || '. Please apply again with all the details.',
          'sent', now());
end;
$$;

revoke all on function public.org_notify_incomplete_application(uuid, text) from public, anon;
grant execute on function public.org_notify_incomplete_application(uuid, text) to authenticated;
