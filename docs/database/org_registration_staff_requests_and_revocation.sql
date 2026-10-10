-- org_registration_staff_requests_and_revocation
--
-- Organisation onboarding and admin control, as asked:
--
--   1. Only an existing UbuntuID citizen can register an organisation: the
--      head's ID number, first name and last name must match a citizen
--      record. The head's cellphone is captured (optional, any format --
--      relaxed 2026-10-10 so it never blocks registration), and the head is told in
--      UbuntuID (their own citizen notifications) when the application is
--      approved or declined.
--   2. Organisations no longer create their own staff. The head/admin sends
--      a staff request (first name, last name, ID number -- each must be a
--      citizen); an UbuntuID administrator approves it, which creates the
--      account as firstname@<organisation domain>, or declines it.
--   3. "Revoke verification" (organisations.verified = false) now really
--      stops the organisation verifying anyone: no new applications and no
--      new checks. Its staff can still sign in and see past results.
--   4. "Revoke access" keeps deleting nothing -- it only flips
--      registration_status -- and now also ends the staff's current
--      sign-in sessions, so they are signed out straight away.
--   5. RLS loopholes closed: an organisation admin could previously UPDATE
--      its own organisations row (including `verified`) and INSERT
--      organisation_users rows directly. Both are now administrator-only;
--      everything an organisation legitimately does goes through the
--      SECURITY DEFINER functions below.
--
-- APPLIED 2026-10-10 via the Supabase Management API.

-- ---------------------------------------------------------------------
-- 0. Columns and the staff-request table
-- ---------------------------------------------------------------------

alter table public.organisation_users add column if not exists cellphone text;

create table if not exists public.organisation_staff_requests (
  request_id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(organisation_id) on delete cascade,
  requested_by_user_id uuid references public.organisation_users(organisation_user_id) on delete set null,
  first_name text not null,
  last_name text not null,
  id_number text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'declined')),
  decline_reason text,
  decided_by_admin_id uuid references public.ubuntuid_administrators(admin_id),
  decided_at timestamptz,
  organisation_user_id uuid references public.organisation_users(organisation_user_id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.organisation_staff_requests enable row level security;

drop policy if exists staff_requests_select on public.organisation_staff_requests;
create policy staff_requests_select on public.organisation_staff_requests for select
  using (organisation_id = (select current_org_id()) or (select is_admin()));
-- No insert/update/delete policies: only the functions below write here.

drop trigger if exists trg_audit_organisation_staff_requests_iu on public.organisation_staff_requests;
create trigger trg_audit_organisation_staff_requests_iu after insert or update on public.organisation_staff_requests
  for each row execute function fn_audit_log('request_id');

-- ---------------------------------------------------------------------
-- 1. Close the RLS loopholes
-- ---------------------------------------------------------------------

drop policy if exists orgs_update on public.organisations;
create policy orgs_update on public.organisations for update
  using ((select is_admin())) with check ((select is_admin()));

drop policy if exists ou_write on public.organisation_users;
create policy ou_write on public.organisation_users for all
  using ((select is_admin())) with check ((select is_admin()));

-- ---------------------------------------------------------------------
-- 2. Helper: is this ID number + name an existing, living citizen?
-- ---------------------------------------------------------------------

create or replace function public._citizen_matches(p_id_number text, p_first_name text, p_last_name text)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select citizen_id from citizens
  where id_number = trim(p_id_number)
    and lower(trim(first_name)) = lower(trim(p_first_name))
    and lower(trim(last_name)) = lower(trim(p_last_name))
    and current_status = 'active'
  limit 1;
$$;

revoke execute on function public._citizen_matches(text, text, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. register_organisation: citizen check + head cellphone
-- ---------------------------------------------------------------------

drop function if exists public.register_organisation(text, text, text, text, text, text[], text, text, text, text, text, jsonb);

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
  p_credential_reasons jsonb default '{}'::jsonb,
  p_head_cellphone text default null
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
  v_cellphone text := nullif(trim(coalesce(p_head_cellphone, '')), '');
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
  if _citizen_matches(p_head_id_number, p_head_first_name, p_head_last_name) is null then
    raise exception 'The organisation head must be an UbuntuID citizen. We could not find a citizen with ID number % '
      'and the name % %. Check the ID number and that your name is spelled as on your ID.',
      trim(p_head_id_number), trim(p_head_first_name), trim(p_head_last_name);
  end if;
  -- The cellphone is stored as typed (optional, any format) -- it's a
  -- contact detail, not something checked against a record.

  v_full_name := trim(concat_ws(' ', p_head_first_name, p_head_last_name));

  insert into organisations (
    legal_name, registration_number, organisation_type, access_tier, verified,
    contact_email, contact_phone, registration_status, requested_at, access_purpose
  ) values (
    p_legal_name, p_registration_number, p_organisation_type, 'basic', false,
    p_contact_email, p_contact_phone, 'pending', now(), nullif(trim(p_access_purpose), '')
  ) returning organisation_id into v_org_id;

  insert into organisation_users (
    auth_user_id, organisation_id, full_name, first_name, last_name, user_role, active, email, gender, id_number, cellphone
  ) values (
    v_uid, v_org_id, v_full_name, p_head_first_name, p_head_last_name, 'manager', true, p_contact_email,
    p_head_gender, trim(p_head_id_number), v_cellphone
  );

  insert into organisation_credential_scopes (organisation_id, credential_type_id, reason)
  select v_org_id, credential_type_id, nullif(trim(coalesce(p_credential_reasons ->> type_code, '')), '')
  from credential_types where type_code = any(p_credential_type_codes);

  return v_org_id;
end;
$$;

grant execute on function public.register_organisation(text, text, text, text, text, text[], text, text, text, text, text, jsonb, text) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Tell the head (as a citizen) about approval/decline/revocation
-- ---------------------------------------------------------------------

create or replace function public._notify_org_head(p_organisation_id uuid, p_message text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into notifications (citizen_id, channel, message, delivery_status, sent_at)
  select c.citizen_id, 'in_app', p_message, 'sent', now()
  from organisation_users u
  join citizens c on c.id_number = u.id_number
  where u.organisation_id = p_organisation_id and u.user_role = 'manager';
end;
$$;

revoke execute on function public._notify_org_head(uuid, text) from public, anon, authenticated;

create or replace function public.admin_review_organisation(p_organisation_id uuid, p_approve boolean, p_notes text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid;
  v_name text;
begin
  select admin_id into v_admin_id from ubuntuid_administrators where auth_user_id = auth.uid() and active;
  if v_admin_id is null then
    raise exception 'Only an administrator can review organisation applications';
  end if;
  if not p_approve and coalesce(trim(p_notes), '') = '' then
    raise exception 'A reason is required to decline an application.';
  end if;

  update organisations set
    registration_status = case when p_approve then 'approved' else 'declined' end,
    verified = p_approve,
    reviewed_by_admin_id = v_admin_id,
    reviewed_at = now(),
    decline_reason = case when p_approve then null else p_notes end
  where organisation_id = p_organisation_id
  returning legal_name into v_name;

  insert into organisation_verifications (organisation_id, verified_by_admin_id, verification_status, evidence_notes)
  values (p_organisation_id, v_admin_id, case when p_approve then 'verified' else 'rejected' end, p_notes);

  perform _notify_org_head(
    p_organisation_id,
    case when p_approve
      then v_name || ' has been approved on UbuntuID. You can now sign in and start verifying applicants.'
      else v_name || '''s UbuntuID application was declined. Reason: ' || trim(p_notes)
           || '. You can correct it and resubmit.'
    end
  );
end;
$$;

-- ---------------------------------------------------------------------
-- 5. Revoke access: nothing deleted, staff signed out straight away
-- ---------------------------------------------------------------------

create or replace function public.admin_revoke_organisation(p_organisation_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_admin_id uuid;
  v_status text;
  v_name text;
begin
  select admin_id into v_admin_id from ubuntuid_administrators where auth_user_id = auth.uid() and active;
  if v_admin_id is null then
    raise exception 'Only an administrator can revoke an organisation.';
  end if;
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'A reason is required to revoke an organisation.';
  end if;

  select registration_status, legal_name into v_status, v_name from organisations where organisation_id = p_organisation_id;
  if v_status is null then
    raise exception 'Organisation not found.';
  end if;
  if v_status = 'revoked' then
    raise exception 'This organisation is already revoked.';
  end if;

  -- Only a status change: applicants, results, employees and staff
  -- accounts all stay exactly as they are, so reinstating restores
  -- everything.
  update organisations set
    registration_status = 'revoked',
    revoked_at = now(),
    revoked_by_admin_id = v_admin_id,
    revoke_reason = p_reason
  where organisation_id = p_organisation_id;

  -- Sign the staff out now: ending their sessions invalidates their
  -- refresh tokens, so the app can't renew their sign-in.
  delete from auth.sessions
  where user_id in (select auth_user_id from public.organisation_users
                    where organisation_id = p_organisation_id and auth_user_id is not null);

  perform _notify_org_head(p_organisation_id,
    v_name || '''s access to UbuntuID has been revoked. Reason: ' || trim(p_reason)
    || '. Your organisation''s records are kept. Contact UbuntuID to have access reinstated.');
end;
$$;

-- ---------------------------------------------------------------------
-- 6. Revoked verification blocks verifying
-- ---------------------------------------------------------------------

create or replace function public._require_org_can_verify(p_org_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not coalesce((select verified from organisations where organisation_id = p_org_id), false) then
    raise exception 'Your organisation''s verification has been revoked by an UbuntuID administrator, so it cannot '
      'verify citizens right now. Your past results are still available. Contact UbuntuID to have it restored.';
  end if;
end;
$$;

revoke execute on function public._require_org_can_verify(uuid) from public, anon, authenticated;

create or replace function public.org_submit_application(p_citizen_id uuid, p_credential_type_ids uuid[], p_claims jsonb default '{}'::jsonb)
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
  perform _require_org_can_verify(v_org_id);
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

create or replace function public.start_verification(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_status text;
begin
  select organisation_id, overall_status into v_org_id, v_status
  from verification_requests where request_id = p_request_id;

  if v_org_id is null then
    raise exception 'Verification request not found.';
  end if;
  if not is_admin() and v_org_id is distinct from current_org_user_organisation_id() then
    raise exception 'Only the requesting organisation may start this verification.';
  end if;
  if not is_admin() then
    perform _require_org_can_verify(v_org_id);
  end if;
  if v_status <> 'pending' then
    raise exception 'This request is "%", not "pending" -- it has already been started or decided.', v_status;
  end if;

  update verification_requests
  set overall_status = 'processing', processing_started_at = now()
  where request_id = p_request_id;
end;
$$;

-- ---------------------------------------------------------------------
-- 7. Staff requests replace organisations creating their own staff
-- ---------------------------------------------------------------------

create or replace function public.org_admin_create_staff(p_first_name text, p_last_name text, p_password text, p_email text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'Organisations can no longer add staff directly. Send a staff request and an UbuntuID administrator will add them.';
end;
$$;

-- p_staff: [{"first_name": "...", "last_name": "...", "id_number": "..."}, ...]
create or replace function public.org_request_staff(p_staff jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller record;
  v_person jsonb;
  v_first text; v_last text; v_id text;
  v_count int := 0;
begin
  select u.organisation_user_id, u.organisation_id, u.user_role into v_caller
  from organisation_users u
  where u.auth_user_id = auth.uid() and u.active
    and u.organisation_id = current_org_user_organisation_id();

  if v_caller is null or v_caller.user_role not in ('manager', 'administrator') then
    raise exception 'Only an approved organisation''s head or admin can request staff.';
  end if;
  if p_staff is null or jsonb_typeof(p_staff) <> 'array' or jsonb_array_length(p_staff) = 0 then
    raise exception 'Add at least one person to the request.';
  end if;

  for v_person in select * from jsonb_array_elements(p_staff) loop
    v_first := trim(coalesce(v_person ->> 'first_name', ''));
    v_last := trim(coalesce(v_person ->> 'last_name', ''));
    v_id := regexp_replace(coalesce(v_person ->> 'id_number', ''), '\s', '', 'g');

    if v_first = '' or v_last = '' or v_id !~ '^[0-9]{13}$' then
      raise exception 'Each person needs a first name, last name and 13-digit ID number.';
    end if;
    if _citizen_matches(v_id, v_first, v_last) is null then
      raise exception '% % (ID %) is not an UbuntuID citizen. Staff must be registered citizens -- check the ID number and the name as spelled on their ID.',
        v_first, v_last, v_id;
    end if;
    if exists (select 1 from organisation_users where organisation_id = v_caller.organisation_id and id_number = v_id) then
      raise exception '% % already has an account at your organisation.', v_first, v_last;
    end if;
    if exists (select 1 from organisation_staff_requests
               where organisation_id = v_caller.organisation_id and id_number = v_id and status = 'pending') then
      raise exception 'There is already a pending request for % %.', v_first, v_last;
    end if;

    insert into organisation_staff_requests (organisation_id, requested_by_user_id, first_name, last_name, id_number)
    values (v_caller.organisation_id, v_caller.organisation_user_id, v_first, v_last, v_id);
    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('requested', v_count);
end;
$$;

grant execute on function public.org_request_staff(jsonb) to authenticated;

create or replace function public.admin_decide_staff_request(
  p_request_id uuid,
  p_approve boolean,
  p_password text default null,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid;
  v_req record;
  v_domain text; v_local text; v_candidate text; v_suffix int := 1; v_email text;
  v_auth_id uuid; v_user_id uuid; v_full_name text; v_gender text;
begin
  select admin_id into v_admin_id from ubuntuid_administrators where auth_user_id = auth.uid() and active;
  if v_admin_id is null then
    raise exception 'Only an administrator can decide staff requests.';
  end if;

  select r.*, o.contact_email, o.legal_name into v_req
  from organisation_staff_requests r join organisations o on o.organisation_id = r.organisation_id
  where r.request_id = p_request_id;
  if v_req is null then
    raise exception 'Staff request not found.';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'This request has already been %.', v_req.status;
  end if;

  if not p_approve then
    if coalesce(trim(p_reason), '') = '' then
      raise exception 'A reason is required to decline a staff request.';
    end if;
    update organisation_staff_requests
       set status = 'declined', decline_reason = trim(p_reason), decided_by_admin_id = v_admin_id, decided_at = now()
     where request_id = p_request_id;
    perform _notify_org_head(v_req.organisation_id,
      'UbuntuID declined your staff request for ' || v_req.first_name || ' ' || v_req.last_name || '. Reason: ' || trim(p_reason));
    return jsonb_build_object('status', 'declined');
  end if;

  if coalesce(length(p_password), 0) < 8 then
    raise exception 'Set a starting password of at least 8 characters.';
  end if;

  -- firstname@<domain>, with kopano2@, kopano3@... if taken.
  v_domain := split_part(coalesce(v_req.contact_email, ''), '@', 2);
  if v_domain = '' then
    raise exception '% has no email domain on record.', v_req.legal_name;
  end if;
  v_local := regexp_replace(lower(v_req.first_name), '[^a-z0-9]', '', 'g');
  v_candidate := v_local || '@' || v_domain;
  while exists (select 1 from organisation_users where lower(email) = v_candidate)
     or exists (select 1 from auth.users where lower(email) = v_candidate) loop
    v_suffix := v_suffix + 1;
    v_candidate := v_local || v_suffix::text || '@' || v_domain;
  end loop;
  v_email := v_candidate;

  v_full_name := v_req.first_name || ' ' || v_req.last_name;
  select gender into v_gender from citizens where id_number = v_req.id_number;
  v_auth_id := _provision_auth_user(v_email, p_password, v_full_name);

  insert into organisation_users (auth_user_id, organisation_id, full_name, first_name, last_name, user_role, active, email, gender, id_number)
  values (v_auth_id, v_req.organisation_id, v_full_name, v_req.first_name, v_req.last_name, 'member', true, v_email, v_gender, v_req.id_number)
  returning organisation_user_id into v_user_id;

  update organisation_staff_requests
     set status = 'approved', decided_by_admin_id = v_admin_id, decided_at = now(), organisation_user_id = v_user_id
   where request_id = p_request_id;

  perform _notify_org_head(v_req.organisation_id,
    'UbuntuID approved your staff request: ' || v_full_name || ' can now sign in as ' || v_email || '.');

  return jsonb_build_object('status', 'approved', 'email', v_email, 'organisation_user_id', v_user_id);
end;
$$;

grant execute on function public.admin_decide_staff_request(uuid, boolean, text, text) to authenticated;
