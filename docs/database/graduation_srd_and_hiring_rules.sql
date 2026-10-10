-- graduation_srd_and_hiring_rules
--
-- Departments keep each other current, so a citizen is never rejected
-- because of somebody else's out-of-date record:
--
--   1. Graduation -- Higher Education sets an enrolment to "Graduated", or
--      records a passing final result -- automatically:
--        * ends the citizen's active NSFAS funding (new funding_status);
--        * records them as Unemployed with Employment and Labour, unless
--          they already have a job;
--        * tells the citizen.
--   2. SASSA can't make an SRD R370 grant Active while Higher Education
--      shows active NSFAS funding or Labour shows the citizen employed.
--      (After graduation, neither is true, so the grant goes through.)
--   3. Being hired -- an organisation's employment offer or a Labour
--      official recording "Employed"/"Self-Employed" -- suspends an active
--      SRD R370 grant and tells the citizen.
--
-- All three run as triggers, so they apply no matter which screen or
-- function writes the record. Setting the session flag
-- `ubuntuid.seeding = on` skips them while loading demo data.
--
-- APPLIED 2026-10-10 via the Supabase Management API.

alter table public.dhet_nsfas_funding
  add column if not exists funding_status text not null default 'Active'
    check (funding_status in ('Active', 'Ended')),
  add column if not exists ended_at timestamptz,
  add column if not exists end_reason text;

create or replace function public._seeding()
returns boolean
language sql
stable
as $$ select coalesce(current_setting('ubuntuid.seeding', true), '') = 'on' $$;

-- Sets the citizen's most recent credential of a type to a status, or
-- issues one if none exists -- the server-side twin of the app's
-- DepartmentRepository._updateCredentialMirror.
create or replace function public._set_credential_status(p_national_id text, p_type_code text, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_citizen_id uuid;
  v_type record;
  v_credential_id uuid;
begin
  select citizen_id into v_citizen_id from citizens where id_number = p_national_id;
  select credential_type_id, issuing_department_id into v_type from credential_types where type_code = p_type_code;
  if v_citizen_id is null or v_type is null then
    return;
  end if;

  select credential_id into v_credential_id from credentials
  where citizen_id = v_citizen_id and credential_type_id = v_type.credential_type_id
  order by issued_date desc nulls last limit 1;

  if v_credential_id is not null then
    update credentials set status = p_status, updated_at = now() where credential_id = v_credential_id;
  else
    insert into credentials (citizen_id, credential_type_id, issuing_department_id, status, issued_date)
    values (v_citizen_id, v_type.credential_type_id, v_type.issuing_department_id, p_status, current_date);
  end if;
end;
$$;

revoke execute on function public._set_credential_status(text, text, text) from public, anon, authenticated;

create or replace function public._notify_citizen_by_id_number(p_national_id text, p_message text)
returns void
language sql
security definer
set search_path = public
as $$
  insert into notifications (citizen_id, channel, message, delivery_status, sent_at)
  select citizen_id, 'in_app', p_message, 'sent', now() from citizens where id_number = p_national_id;
$$;

revoke execute on function public._notify_citizen_by_id_number(text, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 1. Graduation
-- ---------------------------------------------------------------------

create or replace function public._apply_graduation(p_national_id text, p_qualification text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ended int := 0;
  v_latest_status text;
  v_marked_unemployed boolean := false;
  v_message text;
begin
  update dhet_nsfas_funding
     set funding_status = 'Ended', ended_at = now(),
         end_reason = 'Graduated: ' || coalesce(p_qualification, 'qualification completed')
   where national_id_number = p_national_id and approved_status and funding_status = 'Active';
  get diagnostics v_ended = row_count;

  perform _set_credential_status(p_national_id, 'TERTIARY_QUALIFICATION', 'active');

  select employment_status into v_latest_status from labour_employment_records
  where national_id_number = p_national_id order by created_at desc limit 1;

  if v_latest_status is null or v_latest_status not in ('Employed', 'Self-Employed', 'Unemployed') then
    insert into labour_employment_records (national_id_number, employer_name, employment_status, start_date,
                                           uif_contribution_amount, uif_claim_status)
    values (p_national_id, null, 'Unemployed', current_date, 0, 'Not Claiming');
    perform _set_credential_status(p_national_id, 'LABOUR_STATUS', 'suspended');
    v_marked_unemployed := true;
  end if;

  if v_ended > 0 or v_marked_unemployed then
    v_message := 'Congratulations on completing your ' || coalesce(p_qualification, 'qualification') || '.';
    if v_ended > 0 then
      v_message := v_message || ' Your NSFAS funding has ended.';
    end if;
    if v_marked_unemployed then
      v_message := v_message || ' Employment and Labour now lists you as unemployed, so you can download '
        || 'a Confirmation of Unemployment and apply for the SRD R370 grant.';
    end if;
    perform _notify_citizen_by_id_number(p_national_id, v_message);
  end if;
end;
$$;

revoke execute on function public._apply_graduation(text, text) from public, anon, authenticated;

create or replace function public.fn_on_enrolment_graduated()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if _seeding() then return new; end if;
  if new.completion_status = 'Graduated'
     and (tg_op = 'INSERT' or old.completion_status is distinct from 'Graduated') then
    perform _apply_graduation(new.national_id_number, new.qualification_name);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enrolment_graduated on public.dhet_student_enrollment;
create trigger trg_enrolment_graduated after insert or update of completion_status on public.dhet_student_enrollment
  for each row execute function fn_on_enrolment_graduated();

create or replace function public.fn_on_academic_result_passed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if _seeding() then return new; end if;
  if new.final_result <> 'Fail' then
    perform _apply_graduation(new.national_id_number, new.qualification_name);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_academic_result_passed on public.dhet_academic_records;
create trigger trg_academic_result_passed after insert on public.dhet_academic_records
  for each row execute function fn_on_academic_result_passed();

-- ---------------------------------------------------------------------
-- 2. SRD R370 eligibility
-- ---------------------------------------------------------------------

create or replace function public.fn_enforce_srd_eligibility()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nsfas_year int;
  v_employment text;
  v_employer text;
begin
  if _seeding() then return new; end if;
  if new.grant_type <> 'SRD R370' or new.status <> 'Active' then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.status = 'Active' and old.grant_type = 'SRD R370' then
    return new; -- already active; only a change *to* active is checked
  end if;

  select funding_year into v_nsfas_year from dhet_nsfas_funding
  where national_id_number = new.national_id_number and approved_status and funding_status = 'Active'
  order by funding_year desc limit 1;
  if v_nsfas_year is not null then
    raise exception 'Cannot approve the SRD R370 grant: Higher Education shows active NSFAS funding (%) for this citizen. '
      'If they have graduated or left their studies, Higher Education must update the record first.', v_nsfas_year;
  end if;

  select employment_status, employer_name into v_employment, v_employer from labour_employment_records
  where national_id_number = new.national_id_number order by created_at desc limit 1;
  if v_employment in ('Employed', 'Self-Employed') then
    raise exception 'Cannot approve the SRD R370 grant: Employment and Labour lists this citizen as % (%). '
      'The SRD grant is for people with no income.', lower(v_employment), coalesce(v_employer, 'no employer named');
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_srd_eligibility on public.sassa_grants;
create trigger trg_enforce_srd_eligibility before insert or update on public.sassa_grants
  for each row execute function fn_enforce_srd_eligibility();

-- ---------------------------------------------------------------------
-- 3. Hired -> SRD suspended
-- ---------------------------------------------------------------------

create or replace function public.fn_suspend_srd_when_employed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_suspended int := 0;
begin
  if _seeding() then return new; end if;
  if new.employment_status not in ('Employed', 'Self-Employed') then
    return new;
  end if;

  update sassa_grants set status = 'Suspended'
   where national_id_number = new.national_id_number and grant_type = 'SRD R370' and status = 'Active';
  get diagnostics v_suspended = row_count;

  if v_suspended > 0 then
    perform _set_credential_status(new.national_id_number, 'SASSA_STATUS', 'suspended');
    perform _notify_citizen_by_id_number(new.national_id_number,
      'Employment and Labour has recorded that you are now ' || lower(new.employment_status)
      || coalesce(' at ' || new.employer_name, '') || ', so SASSA has suspended your SRD R370 grant. '
      || 'If this changes, you can apply again.');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_suspend_srd_when_employed on public.labour_employment_records;
create trigger trg_suspend_srd_when_employed after insert on public.labour_employment_records
  for each row execute function fn_suspend_srd_when_employed();

-- ---------------------------------------------------------------------
-- 4. Backfill: funding for people whose latest enrolment is no longer
--    "Enrolled" ended when they left -- mark it so.
-- ---------------------------------------------------------------------

update public.dhet_nsfas_funding f
   set funding_status = 'Ended', ended_at = now(),
       end_reason = 'Backfilled: latest enrolment is ' || e.completion_status
  from (select distinct on (national_id_number) national_id_number, completion_status
          from public.dhet_student_enrollment order by national_id_number, created_at desc) e
 where e.national_id_number = f.national_id_number
   and e.completion_status <> 'Enrolled'
   and f.funding_status = 'Active';
