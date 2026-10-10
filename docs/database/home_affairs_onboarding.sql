-- home_affairs_onboarding
--
-- Home Affairs already holds every South African's identity -- the
-- population register -- and each department already holds its own records
-- against the person's ID number. UbuntuID doesn't create those people; it
-- gives them a digital ID. A citizen row with no email and no auth account
-- is someone in the register who isn't on UbuntuID yet.
--
-- Onboarding (a Home Affairs official):
--   1. dha_find_citizen(id)   -- looks the ID number up in the register and
--      summarises the records every department already holds.
--   2. dha_onboard_citizen(...) -- adds the citizen's email/phone and turns
--      every existing department record into a credential, so all their
--      documents (matric, degree, licence, passport, tax, clearance,
--      employment, grants) appear the moment they sign up.
--   The citizen then uses "Create account" with that email
--   (claim_citizen_account links it, unchanged).
--
-- _sync_citizen_credentials is also safe to run again later: it only adds
-- credentials that are missing, never overwrites one.
--
-- APPLIED 2026-10-10 via the Supabase Management API.

create or replace function public._sync_citizen_credentials(p_citizen_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id text;
  v_created int := 0;
  v_status text;
  v_issued date;
  v_expiry date;
  v_code text;
begin
  select id_number into v_id from citizens where citizen_id = p_citizen_id;
  if v_id is null then
    return 0;
  end if;

  for v_code in select unnest(array['PASSPORT', 'DRIVERS_LICENCE', 'TAX_COMPLIANCE', 'CRIMINAL_CLEARANCE',
                                    'NSC', 'TERTIARY_QUALIFICATION', 'LABOUR_STATUS', 'SASSA_STATUS']) loop
    v_status := null; v_issued := null; v_expiry := null;

    if v_code = 'PASSPORT' then
      select lower(status), issue_date, expiry_date into v_status, v_issued, v_expiry
      from dha_passports where national_id_number = v_id order by issue_date desc limit 1;
    elsif v_code = 'DRIVERS_LICENCE' then
      select case status when 'Valid' then 'active' else lower(status) end, issue_date, expiry_date
        into v_status, v_issued, v_expiry
      from dot_driver_licences where national_id_number = v_id order by issue_date desc limit 1;
    elsif v_code = 'TAX_COMPLIANCE' then
      select case when tax_compliance_status = 'Compliant' then 'active' else 'suspended' end, registered_date
        into v_status, v_issued
      from sars_taxpayers where national_id_number = v_id order by registered_date desc limit 1;
    elsif v_code = 'CRIMINAL_CLEARANCE' then
      select case when status = 'Clear' then 'active' else 'suspended' end, issue_date into v_status, v_issued
      from saps_clearance_certificates where national_id_number = v_id order by issue_date desc limit 1;
    elsif v_code = 'NSC' then
      select 'active', make_date(year, 12, 31) into v_status, v_issued
      from dbe_nsc_results where national_id_number = v_id order by year desc limit 1;
    elsif v_code = 'TERTIARY_QUALIFICATION' then
      -- A finished qualification's result outranks an enrolment status.
      select case when final_result = 'Fail' then 'suspended' else 'active' end, make_date(year, 12, 31)
        into v_status, v_issued
      from dhet_academic_records where national_id_number = v_id order by year desc limit 1;
      if v_status is null then
        select case when completion_status = 'Graduated' then 'active' else 'pending' end, created_at::date
          into v_status, v_issued
        from dhet_student_enrollment where national_id_number = v_id order by created_at desc limit 1;
      end if;
    elsif v_code = 'LABOUR_STATUS' then
      select case when employment_status = 'Unemployed' then 'suspended' else 'active' end, start_date
        into v_status, v_issued
      from labour_employment_records where national_id_number = v_id order by created_at desc limit 1;
    elsif v_code = 'SASSA_STATUS' then
      select lower(status), created_at::date into v_status, v_issued
      from sassa_grants where national_id_number = v_id order by created_at desc limit 1;
    end if;

    if v_status is not null and not exists (
      select 1 from credentials c join credential_types t on t.credential_type_id = c.credential_type_id
      where c.citizen_id = p_citizen_id and t.type_code = v_code
    ) then
      insert into credentials (citizen_id, credential_type_id, issuing_department_id, status, issued_date, expiry_date)
      select p_citizen_id, credential_type_id, issuing_department_id, v_status, coalesce(v_issued, current_date), v_expiry
      from credential_types where type_code = v_code;
      v_created := v_created + 1;
    end if;
  end loop;

  return v_created;
end;
$$;

revoke execute on function public._sync_citizen_credentials(uuid) from public, anon, authenticated;

create or replace function public._require_home_affairs()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not (is_official() and current_official_department_code() = 'HOME_AFFAIRS') then
    raise exception 'Only an active Home Affairs official can onboard citizens.';
  end if;
end;
$$;

revoke execute on function public._require_home_affairs() from public, anon, authenticated;

create or replace function public.dha_find_citizen(p_id_number text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id text := regexp_replace(coalesce(p_id_number, ''), '\s', '', 'g');
  c record;
  v_records jsonb;
begin
  perform _require_home_affairs();

  select * into c from citizens where id_number = v_id;
  if c is null then
    return jsonb_build_object('found', false, 'id_number', v_id);
  end if;

  select coalesce(jsonb_agg(r) filter (where (r ->> 'count')::int > 0), '[]'::jsonb) into v_records
  from (values
    (jsonb_build_object('department', 'Basic Education', 'record', 'Matric certificate',
      'count', (select count(*) from dbe_nsc_results where national_id_number = v_id))),
    (jsonb_build_object('department', 'Higher Education', 'record', 'University or college enrolment',
      'count', (select count(*) from dhet_student_enrollment where national_id_number = v_id))),
    (jsonb_build_object('department', 'Higher Education', 'record', 'Academic results',
      'count', (select count(*) from dhet_academic_records where national_id_number = v_id))),
    (jsonb_build_object('department', 'Higher Education', 'record', 'NSFAS funding',
      'count', (select count(*) from dhet_nsfas_funding where national_id_number = v_id))),
    (jsonb_build_object('department', 'Transport', 'record', 'Driver''s licence',
      'count', (select count(*) from dot_driver_licences where national_id_number = v_id))),
    (jsonb_build_object('department', 'Home Affairs', 'record', 'Passport',
      'count', (select count(*) from dha_passports where national_id_number = v_id))),
    (jsonb_build_object('department', 'SARS', 'record', 'Tax registration',
      'count', (select count(*) from sars_taxpayers where national_id_number = v_id))),
    (jsonb_build_object('department', 'SAPS', 'record', 'Police clearance',
      'count', (select count(*) from saps_clearance_certificates where national_id_number = v_id))),
    (jsonb_build_object('department', 'Employment and Labour', 'record', 'Employment status',
      'count', (select count(*) from labour_employment_records where national_id_number = v_id))),
    (jsonb_build_object('department', 'SASSA', 'record', 'Social grants',
      'count', (select count(*) from sassa_grants where national_id_number = v_id)))
  ) as t(r);

  return jsonb_build_object(
    'found', true,
    'citizen_id', c.citizen_id,
    'id_number', c.id_number,
    'first_name', c.first_name,
    'last_name', c.last_name,
    'date_of_birth', c.date_of_birth,
    'gender', c.gender,
    'current_status', c.current_status,
    'has_digital_id', (c.email is not null or c.auth_user_id is not null),
    'email', c.email,
    'records', v_records
  );
end;
$$;

grant execute on function public.dha_find_citizen(text) to authenticated;

create or replace function public.dha_onboard_citizen(p_citizen_id uuid, p_email text, p_phone_number text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  c record;
  v_created int;
begin
  perform _require_home_affairs();

  select * into c from citizens where citizen_id = p_citizen_id;
  if c is null then
    raise exception 'Citizen not found in the population register.';
  end if;
  if c.current_status <> 'active' then
    raise exception 'This person''s status is "%", so a digital ID cannot be issued.', c.current_status;
  end if;
  if c.email is not null or c.auth_user_id is not null then
    raise exception '% % already has a digital ID (registered email %).', c.first_name, c.last_name, coalesce(c.email, 'on file');
  end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Enter the citizen''s own email address.';
  end if;
  if exists (select 1 from citizens where lower(email) = v_email) then
    raise exception 'Another citizen is already registered with this email address.';
  end if;

  update citizens
     set email = v_email,
         phone_number = coalesce(nullif(trim(p_phone_number), ''), phone_number),
         updated_at = now()
   where citizen_id = p_citizen_id;

  v_created := _sync_citizen_credentials(p_citizen_id);

  insert into notifications (citizen_id, channel, message, delivery_status, sent_at)
  values (p_citizen_id, 'in_app',
    'Welcome to UbuntuID. Home Affairs has issued your digital ID, and ' || v_created ||
    ' of your existing government records are now in your documents.', 'sent', now());

  return jsonb_build_object('citizen_id', p_citizen_id, 'email', v_email, 'credentials_linked', v_created);
end;
$$;

grant execute on function public.dha_onboard_citizen(uuid, text, text) to authenticated;
