-- "All officials and admins should also be citizens" -- in reality a
-- government official or platform administrator is still a citizen with
-- their own digital identity, separate from their work login (role_
-- service.dart resolves one auth_user_id to exactly one role, first match
-- wins with citizens checked first -- so this is deliberately a SEPARATE
-- citizen identity/login for the same real person, not the same
-- auth_user_id as their work account, exactly like a real person has a
-- personal ID separate from a work badge). Uses their existing id_number
-- (one real person, one SA ID number, whichever role table it's read
-- from), with date_of_birth derived from it the same way
-- `saIdDateOfBirth` does client-side (2000+yy, or 1900+yy if that's in
-- the future).
--
-- APPLIED live via the Supabase MCP in two migrations:
-- `officials_and_admins_are_also_citizens` (the citizens rows) then
-- `enrich_official_citizens_qualifications` (matric/tertiary/licence/tax/
-- employment/passport + matching credentials, reflecting that these are
-- working professionals). Both below, in order.

-- === Migration 1: officials_and_admins_are_also_citizens ===

create table public._seed_officials_as_citizens (
  citizen_id uuid,
  id_number text,
  source_kind text,
  full_name text,
  department_name text
);

do $$
declare
  r record;
  v_dob date;
  v_email text;
  v_citizen_id uuid;
  v_yy int;
  v_mm int;
  v_dd int;
  v_year int;
  v_domains text[] := array['gmail.com','yahoo.com','outlook.com','webmail.co.za'];
  i int := 0;
begin
  for r in
    select 'official' as kind, o.id_number, o.first_name, o.last_name, o.gender, o.full_name,
      d.department_name
    from department_officials o
    join departments d on d.department_id = o.department_id
    union all
    select 'administrator' as kind, a.id_number, a.first_name, a.last_name, a.gender, a.full_name,
      'UbuntuID Administration' as department_name
    from ubuntuid_administrators a
  loop
    i := i + 1;
    v_yy := substring(r.id_number from 1 for 2)::int;
    v_mm := substring(r.id_number from 3 for 2)::int;
    v_dd := substring(r.id_number from 5 for 2)::int;
    v_year := 2000 + v_yy;
    if v_year > extract(year from current_date)::int then v_year := v_year - 100; end if;
    v_dob := make_date(v_year, greatest(v_mm,1), greatest(v_dd,1));

    v_email := lower(regexp_replace(r.first_name, '[^a-zA-Z0-9]', '', 'g')) || '.' ||
               lower(regexp_replace(r.last_name, '[^a-zA-Z0-9]', '', 'g')) || '.citizen' || i::text || '@' ||
               v_domains[1 + (i % array_length(v_domains,1))];

    insert into citizens (id_number, first_name, last_name, date_of_birth, current_status,
      registration_source, phone_number, email, gender, citizenship_status, is_active)
    values (r.id_number, r.first_name, r.last_name, v_dob, 'active', 'opt_in_migration',
      '0' || (60 + floor(random()*40))::text || (1000000 + floor(random()*8999999))::text,
      v_email, r.gender, 'citizen', true)
    returning citizen_id into v_citizen_id;

    insert into public._seed_officials_as_citizens (citizen_id, id_number, source_kind, full_name, department_name)
    values (v_citizen_id, r.id_number, r.kind, r.full_name, r.department_name);

    insert into notifications (citizen_id, channel, message, delivery_status, sent_at, is_read)
    values (v_citizen_id, 'in_app',
      'Welcome to UbuntuID, ' || r.first_name || '! Your personal digital identity is now active, separate from your staff login.',
      'sent', now(), false);
  end loop;
end $$;

-- === Migration 2: enrich_official_citizens_qualifications ===
-- (staging table from migration 1 still present at this point)

do $$
declare
  r record;
  passport_seq int;
  licence_seq int;
  tax_seq int;
  matric_seq int;
  ct_passport record;
  ct_licence record;
  ct_tax record;
  ct_nsc record;
  ct_tertiary record;
  ct_labour record;
  quals text[] := array['BCom Accounting','BA Public Administration','BSc Information Technology',
    'LLB Law','BSocSci Political Science','BAdmin Honours','MPhil Public Policy','BEng Industrial Engineering'];
  results text[] := array['Distinction','Merit','Pass'];
  institutions text[] := array['UCT','UKZN','UP','WITS','NMU','SU'];
  v_inst text;
  v_qual text;
  v_year int;
  v_matric_num text;
  v_licence_num text;
  v_tax_num text;
  v_passport_num text;
  i int := 0;
begin
  select credential_type_id, issuing_department_id into ct_passport from credential_types where type_code='PASSPORT';
  select credential_type_id, issuing_department_id into ct_licence from credential_types where type_code='DRIVERS_LICENCE';
  select credential_type_id, issuing_department_id into ct_tax from credential_types where type_code='TAX_COMPLIANCE';
  select credential_type_id, issuing_department_id into ct_nsc from credential_types where type_code='NSC';
  select credential_type_id, issuing_department_id into ct_tertiary from credential_types where type_code='TERTIARY_QUALIFICATION';
  select credential_type_id, issuing_department_id into ct_labour from credential_types where type_code='LABOUR_STATUS';

  select coalesce(max(substring(passport_number from 2)::bigint), 0) into passport_seq from dha_passports where passport_number ~ '^A[0-9]+$';
  select coalesce(max(licence_number::bigint), 0) into licence_seq from dot_driver_licences where licence_number ~ '^[0-9]+$';
  select coalesce(max(tax_number::bigint), 0) into tax_seq from sars_taxpayers where tax_number ~ '^[0-9]+$';
  select coalesce(max(matric_exam_number::bigint), 100000) into matric_seq from dbe_nsc_results where matric_exam_number ~ '^[0-9]+$';

  for r in select citizen_id, id_number, full_name, department_name from _seed_officials_as_citizens order by id_number loop
    i := i + 1;

    -- Matric
    matric_seq := matric_seq + 1;
    v_matric_num := matric_seq::text;
    v_year := 1995 + (i % 20);
    insert into dbe_nsc_results (matric_exam_number, national_id_number, year, overall_pass_status)
    values (v_matric_num, r.id_number, v_year, 'Bachelor Pass');
    insert into credentials (citizen_id, credential_type_id, issuing_department_id, status, issued_date)
    values (r.citizen_id, ct_nsc.credential_type_id, ct_nsc.issuing_department_id, 'active', make_date(v_year,1,10));

    -- Tertiary qualification (academic record -- a real transcript row, not just enrolment)
    v_inst := institutions[1 + (i % array_length(institutions,1))];
    v_qual := quals[1 + (i % array_length(quals,1))];
    insert into dhet_academic_records (national_id_number, institution_code, qualification_name, year, final_result)
    values (r.id_number, v_inst, v_qual, v_year + 4, results[1 + (i % 3)]);
    insert into dhet_student_enrollment (national_id_number, institution_code, qualification_name, completion_status)
    values (r.id_number, v_inst, v_qual, 'Graduated');
    insert into credentials (citizen_id, credential_type_id, issuing_department_id, status, issued_date)
    values (r.citizen_id, ct_tertiary.credential_type_id, ct_tertiary.issuing_department_id, 'active', make_date(v_year+4,1,10));

    -- Driver's licence
    licence_seq := licence_seq + 1;
    v_licence_num := lpad(licence_seq::text, 10, '0');
    insert into dot_driver_licences (licence_number, national_id_number, licence_code, issue_date, expiry_date, status)
    values (v_licence_num, r.id_number, 'Code B', current_date - interval '5 years', current_date + interval '5 years', 'Valid');
    insert into credentials (citizen_id, credential_type_id, issuing_department_id, status, issued_date, expiry_date)
    values (r.citizen_id, ct_licence.credential_type_id, ct_licence.issuing_department_id, 'active',
      current_date - interval '5 years', current_date + interval '5 years');

    -- Tax compliance
    tax_seq := tax_seq + 1;
    v_tax_num := lpad(tax_seq::text, 10, '0');
    insert into sars_taxpayers (tax_number, national_id_number, tax_compliance_status, registered_date)
    values (v_tax_num, r.id_number, 'Compliant', current_date - interval '6 years');
    insert into sars_tax_returns (tax_number, tax_year, declared_income, refund_or_due_amount, filing_status)
    values (v_tax_num, 2025, 320000 + floor(random()*380000)::int, floor(random()*8000)::int, 'Paid');
    insert into credentials (citizen_id, credential_type_id, issuing_department_id, status, issued_date)
    values (r.citizen_id, ct_tax.credential_type_id, ct_tax.issuing_department_id, 'active', current_date - interval '6 years');

    -- Employment -- at their own real department, professional salary/UIF
    insert into labour_employment_records
      (national_id_number, employer_name, employment_status, start_date, uif_contribution_amount, uif_claim_status)
    values (r.id_number, r.department_name, 'Employed', current_date - interval '4 years',
      round((350 + random()*550)::numeric, 2), 'Not Claiming');
    insert into credentials (citizen_id, credential_type_id, issuing_department_id, status, issued_date)
    values (r.citizen_id, ct_labour.credential_type_id, ct_labour.issuing_department_id, 'active', current_date - interval '4 years');

    -- Passport for about half
    if i % 2 = 0 then
      passport_seq := passport_seq + 1;
      v_passport_num := 'A' || lpad(passport_seq::text, 8, '0');
      insert into dha_passports (passport_number, national_id_number, issue_date, expiry_date, status)
      values (v_passport_num, r.id_number, current_date - interval '3 years', current_date + interval '7 years', 'Active');
      insert into credentials (citizen_id, credential_type_id, issuing_department_id, status, issued_date, expiry_date)
      values (r.citizen_id, ct_passport.credential_type_id, ct_passport.issuing_department_id, 'active',
        current_date - interval '3 years', current_date + interval '7 years');
    end if;
  end loop;
end $$;

drop table public._seed_officials_as_citizens;
