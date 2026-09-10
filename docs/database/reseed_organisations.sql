-- reseed_organisations
--
-- Replaces every existing organisation with real-sounding South African
-- companies/NGOs, each with a head plus real worker accounts (not just one
-- login per organisation) -- matches the user's ask directly: "add new
-- ones with real names including workers".
--
-- Deletes cascade in dependency order first (any prior verification/
-- appeal/employment-offer activity tied to the old organisations goes with
-- them -- there is no way to "reseed the organisation" while keeping its
-- history, since the whole point is starting clean). Citizens, department
-- officials, and departments are untouched.
--
-- Each organisation gets `organisation_credential_scopes` matched to what
-- that kind of business would realistically want to check (a bank cares
-- about tax compliance and qualifications; a retailer cares about matric
-- and a clean criminal record; a security company cares heavily about
-- criminal clearance), a head (`user_role = 'manager'`, matching
-- `register_organisation`'s own convention) and two ordinary staff
-- (`user_role = 'member'`) who can also submit applications day to day.
--
-- APPLIED 2026-09-10 via Supabase MCP.

-- ---------------------------------------------------------------------
-- 1. Clear out every existing organisation and its dependents
-- ---------------------------------------------------------------------

delete from organisation_employees;
delete from verification_results where request_id in (select request_id from verification_requests);
delete from verification_requests;
delete from consent_grants;
delete from organisation_verifications;
delete from organisation_credential_scopes;
-- Old staff logins too -- otherwise they're orphaned auth accounts nobody
-- can reach through the app any more but that still exist.
delete from auth.users where id in (select auth_user_id from organisation_users where auth_user_id is not null);
delete from organisation_users;
delete from organisations;

-- ---------------------------------------------------------------------
-- 2. New organisations, each with a head + 2 workers
-- ---------------------------------------------------------------------

do $$
declare
  v_org_id uuid;
  v_auth_id uuid;

  -- One row per organisation: legal name, registration number, type,
  -- contact email/phone, credential type codes it can verify, and its
  -- 3 staff (full_name, role, gender) -- role 'manager' for the head,
  -- 'member' for ordinary workers.
  orgs jsonb := '[
    {
      "legal_name": "Pick n Pay Stores Limited",
      "registration_number": "1969/000038/06",
      "organisation_type": "private",
      "contact_email": "hr@pnp-hiring.co.za",
      "contact_phone": "0214581000",
      "scopes": ["NSC", "DRIVERS_LICENCE", "CRIMINAL_CLEARANCE"],
      "staff": [
        {"full_name": "Nomsa Khumalo", "role": "manager", "gender": "female"},
        {"full_name": "Riaan Botha", "role": "member", "gender": "male"},
        {"full_name": "Ayesha Patel", "role": "member", "gender": "female"}
      ]
    },
    {
      "legal_name": "Shoprite Holdings Ltd",
      "registration_number": "1936/007721/06",
      "organisation_type": "private",
      "contact_email": "recruitment@shoprite-hiring.co.za",
      "contact_phone": "0219806100",
      "scopes": ["NSC", "CRIMINAL_CLEARANCE", "LABOUR_STATUS"],
      "staff": [
        {"full_name": "Thabo Mahlangu", "role": "manager", "gender": "male"},
        {"full_name": "Bongiwe Dlamini", "role": "member", "gender": "female"}
      ]
    },
    {
      "legal_name": "Standard Bank of South Africa Limited",
      "registration_number": "1962/000738/06",
      "organisation_type": "financial",
      "contact_email": "talent@standardbank-hiring.co.za",
      "contact_phone": "0116361000",
      "scopes": ["NSC", "TERTIARY_QUALIFICATION", "TAX_COMPLIANCE", "CRIMINAL_CLEARANCE"],
      "staff": [
        {"full_name": "Karabo Sekgobela", "role": "manager", "gender": "male"},
        {"full_name": "Chantal Fortune", "role": "member", "gender": "female"},
        {"full_name": "Devan Naidoo", "role": "member", "gender": "male"}
      ]
    },
    {
      "legal_name": "Vodacom (Pty) Ltd",
      "registration_number": "1993/003367/07",
      "organisation_type": "private",
      "contact_email": "careers@vodacom-hiring.co.za",
      "contact_phone": "0821601000",
      "scopes": ["NSC", "TERTIARY_QUALIFICATION", "DRIVERS_LICENCE"],
      "staff": [
        {"full_name": "Lerato Mokoena", "role": "manager", "gender": "female"},
        {"full_name": "Sipho Buthelezi", "role": "member", "gender": "male"}
      ]
    },
    {
      "legal_name": "Thuso Community Development NGO",
      "registration_number": "045-923-NPO",
      "organisation_type": "ngo",
      "contact_email": "admin@thuso-cd.org.za",
      "contact_phone": "0315551234",
      "scopes": ["NSC", "SASSA_STATUS", "LABOUR_STATUS"],
      "staff": [
        {"full_name": "Precious Govender", "role": "manager", "gender": "female"},
        {"full_name": "Given Nkosi", "role": "member", "gender": "male"}
      ]
    },
    {
      "legal_name": "Fidelity Security Services (Pty) Ltd",
      "registration_number": "1996/012789/07",
      "organisation_type": "private",
      "contact_email": "vetting@fidelity-hiring.co.za",
      "contact_phone": "0113865300",
      "scopes": ["NSC", "DRIVERS_LICENCE", "CRIMINAL_CLEARANCE"],
      "staff": [
        {"full_name": "Johan Steyn", "role": "manager", "gender": "male"},
        {"full_name": "Zinhle Sithole", "role": "member", "gender": "female"},
        {"full_name": "Imraan Isaacs", "role": "member", "gender": "male"}
      ]
    }
  ]'::jsonb;

  org record;
  staff_member record;
  v_email text;
  v_id_number text;
  v_name_parts text[];
begin
  for org in select * from jsonb_to_recordset(orgs) as x(
    legal_name text, registration_number text, organisation_type text,
    contact_email text, contact_phone text, scopes jsonb, staff jsonb
  )
  loop
    insert into organisations (
      legal_name, registration_number, organisation_type, access_tier, verified,
      contact_email, contact_phone, registration_status, reviewed_at
    )
    values (
      org.legal_name, org.registration_number, org.organisation_type, 'basic', true,
      org.contact_email, org.contact_phone, 'approved', now()
    )
    returning organisation_id into v_org_id;

    insert into organisation_credential_scopes (organisation_id, credential_type_id)
    select v_org_id, credential_type_id from credential_types
    where type_code in (select jsonb_array_elements_text(org.scopes));

    for staff_member in select * from jsonb_to_recordset(org.staff) as y(full_name text, role text, gender text)
    loop
      v_name_parts := regexp_split_to_array(staff_member.full_name, ' ');
      v_email := lower(v_name_parts[1]) || '.' || lower(v_name_parts[2]) || '@' ||
        regexp_replace(lower(org.legal_name), '[^a-z]', '', 'g') || '.co.za';
      -- Working-age adults: DOB between 1971-01-01 and 2003-01-01 (23-55
      -- years old as of 2026), not an unconstrained random range.
      v_id_number := generate_sa_id_number(
        (date '1971-01-01' + (floor(random() * 11688))::int),
        staff_member.gender, 'citizen'
      );

      -- Password convention: lower(firstname)@123.
      v_auth_id := _provision_auth_user(v_email, lower(v_name_parts[1]) || '@123', staff_member.full_name);

      insert into organisation_users (
        auth_user_id, organisation_id, full_name, user_role, active, email, gender,
        first_name, last_name, id_number
      )
      values (
        v_auth_id, v_org_id, staff_member.full_name, staff_member.role, true, v_email, staff_member.gender,
        v_name_parts[1], v_name_parts[2], v_id_number
      );
    end loop;
  end loop;
end $$;

select o.legal_name, count(u.organisation_user_id) as staff_count
from organisations o left join organisation_users u on u.organisation_id = o.organisation_id
group by o.legal_name order by o.legal_name;
