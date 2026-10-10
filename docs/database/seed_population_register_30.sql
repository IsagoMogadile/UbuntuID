-- seed_population_register_30
--
-- 30 South Africans who exist in the Home Affairs population register and
-- already have records with other departments, but are NOT on UbuntuID yet:
-- no email, no auth account, no credentials. A Home Affairs official finds
-- them by ID number ("Onboard citizen") and issues their digital ID, which
-- links every record below as a credential (dha_onboard_citizen).
--
-- Profiles:
--   student    (6)  matric, enrolled full-time, active NSFAS
--   graduate   (6)  matric, graduated (enrolment + result), NSFAS ended,
--                   Labour: Unemployed; 3 got a licence while studying
--   worker    (10)  matric, degree, licence, tax compliant, employed,
--                   police clearance clear; 4 hold a passport
--   srd        (4)  matric, unemployed, SRD R370 active
--   parent     (2)  matric, unemployed, Child Support grant active
--   record     (2)  working, but a criminal record, clearance "Record
--                   Found" and tax non-compliant
--
-- ID numbers are generated (valid Luhn, gender digits) on insert, so they
-- differ per run. Find them afterwards with:
--   select first_name, last_name, id_number from citizens
--   where registration_source = 'home_affairs_auto' and email is null order by last_name;
--
-- The cross-department triggers are switched off for the load
-- (ubuntuid.seeding) so loading history doesn't send notifications.
--
-- APPLIED 2026-10-10 via the Supabase Management API.

do $$
declare
  p record;
  v_id text;
  v_year int := extract(year from current_date)::int;
  v_matric_year int;
  v_inst text;
  v_qual text;
  i int := 0;
  v_institutions text[] := array['UCT', 'WITS', 'UKZN', 'UP', 'SU', 'NMU', 'CPUT TVET', 'Tshwane North TVET'];
  v_quals text[] := array['BCom Accounting', 'BSc Computer Science', 'LLB Law', 'BEd Foundation Phase',
                          'Diploma in Information Technology', 'BSc Nursing', 'BEng Civil Engineering', 'BA Social Sciences'];
  v_employers text[] := array['Karoo Logistics', 'Ubuntu Bank', 'Coastal Tech Solutions', 'Metro Health Clinic',
                              'Sunrise Retail', 'Highveld Engineering', 'Cape Legal Partners', 'Thusong Schools Trust',
                              'Mzansi Telecoms', 'Durban Port Services'];
begin
  perform set_config('ubuntuid.seeding', 'on', true);

  for p in
    select * from (values
      ('Lerato','Mokoena','female','2004-03-14','student', false),
      ('Sipho','Dlamini','male','2005-07-22','student', false),
      ('Thandeka','Nkosi','female','2004-11-02','student', false),
      ('Kagiso','Molefe','male','2003-09-18','student', false),
      ('Ayanda','Zulu','female','2005-01-27','student', false),
      ('Tshepo','Mahlangu','male','2004-05-09','student', false),
      ('Nomvula','Sithole','female','2002-08-30','graduate', true),
      ('Lwazi','Ndlovu','male','2002-02-15','graduate', true),
      ('Palesa','Mofokeng','female','2003-04-21','graduate', false),
      ('Mandla','Shabalala','male','2001-12-05','graduate', true),
      ('Zanele','Mthembu','female','2002-10-11','graduate', false),
      ('Karabo','Tau','male','2003-01-19','graduate', false),
      ('Thabo','Nkuna','male','1990-03-03','worker', true),
      ('Naledi','Radebe','female','1988-07-19','worker', false),
      ('Johan','van der Merwe','male','1985-11-25','worker', true),
      ('Fatima','Patel','female','1992-01-08','worker', false),
      ('Sizwe','Ngcobo','male','1983-05-30','worker', true),
      ('Busisiwe','Cele','female','1995-09-14','worker', false),
      ('Pieter','Botha','male','1980-02-17','worker', true),
      ('Refilwe','Sebola','female','1993-06-06','worker', false),
      ('Kabelo','Moloi','male','1987-12-12','worker', false),
      ('Ntombi','Mabaso','female','1991-04-04','worker', false),
      ('Vusi','Mathebula','male','1996-08-08','srd', false),
      ('Precious','Maluleke','female','1999-03-23','srd', false),
      ('Themba','Gumede','male','1994-10-30','srd', false),
      ('Lindiwe','Mkhize','female','1998-12-01','srd', false),
      ('Nokuthula','Hadebe','female','1993-02-28','parent', false),
      ('Zodwa','Shezi','female','1990-11-16','parent', false),
      ('Sibusiso','Nxumalo','male','1989-07-07','record', false),
      ('Andile','Mbatha','male','1986-01-20','record', false)
    ) as t(first_name, last_name, gender, dob, profile, extra)
  loop
    i := i + 1;
    v_inst := v_institutions[1 + (i % array_length(v_institutions, 1))];
    v_qual := v_quals[1 + (i % array_length(v_quals, 1))];
    v_matric_year := extract(year from p.dob::date)::int + 18;

    loop
      v_id := generate_sa_id_number(p.dob::date, p.gender, 'citizen');
      exit when not exists (select 1 from citizens where id_number = v_id);
    end loop;

    -- In the register, not on UbuntuID: no email, no auth account.
    insert into citizens (id_number, first_name, last_name, date_of_birth, gender, current_status,
                          registration_source, citizenship_status, is_active)
    values (v_id, p.first_name, p.last_name, p.dob::date, p.gender, 'active', 'home_affairs_auto', 'citizen', true);

    -- Everyone finished school.
    insert into dbe_nsc_results (matric_exam_number, national_id_number, year, overall_pass_status)
    values (next_matric_exam_number(), v_id, v_matric_year,
            case when p.profile in ('student', 'graduate', 'worker') then 'Bachelor Pass' else 'NSC Pass' end);

    if p.profile = 'student' then
      insert into dhet_student_enrollment (national_id_number, institution_code, qualification_name, completion_status, study_mode)
      values (v_id, v_inst, v_qual, 'Enrolled', 'Full-time');
      insert into dhet_nsfas_funding (national_id_number, funding_year, approved_status, disbursed_amount, funding_status)
      values (v_id, v_year, true, 45000, 'Active');

    elsif p.profile = 'graduate' then
      insert into dhet_student_enrollment (national_id_number, institution_code, qualification_name, completion_status, study_mode, created_at)
      values (v_id, v_inst, v_qual, 'Graduated', 'Full-time', now() - interval '30 days');
      insert into dhet_academic_records (national_id_number, institution_code, qualification_name, year, final_result)
      values (v_id, v_inst, v_qual, v_year, case when i % 3 = 0 then 'Distinction' when i % 3 = 1 then 'Merit' else 'Pass' end);
      insert into dhet_nsfas_funding (national_id_number, funding_year, approved_status, disbursed_amount,
                                      funding_status, ended_at, end_reason)
      values (v_id, v_year, true, 45000, 'Ended', now() - interval '30 days', 'Graduated: ' || v_qual);
      insert into labour_employment_records (national_id_number, employer_name, employment_status, start_date,
                                             uif_contribution_amount, uif_claim_status)
      values (v_id, null, 'Unemployed', current_date - 30, 0, 'Not Claiming');
      if p.extra then -- licence obtained during their studies
        insert into dot_driver_licences (licence_number, national_id_number, licence_code, issue_date, expiry_date, status)
        values (next_licence_number(), v_id, 'Code B', (p.dob::date + interval '20 years')::date,
                (p.dob::date + interval '25 years')::date, 'Valid');
      end if;

    elsif p.profile in ('worker', 'record') then
      insert into dhet_academic_records (national_id_number, institution_code, qualification_name, year, final_result)
      values (v_id, v_inst, v_qual, v_matric_year + 4, 'Pass');
      insert into dot_driver_licences (licence_number, national_id_number, licence_code, issue_date, expiry_date, status)
      values (next_licence_number(), v_id, case when i % 4 = 0 then 'Code EB' else 'Code B' end,
              current_date - 400, current_date + 1425, 'Valid');
      insert into sars_taxpayers (tax_number, national_id_number, tax_compliance_status, registered_date)
      values (next_tax_number(), v_id, case when p.profile = 'record' then 'Non-Compliant' else 'Compliant' end,
              make_date(v_matric_year + 5, 3, 1));
      insert into labour_employment_records (national_id_number, employer_name, employment_status, start_date,
                                             uif_contribution_amount, uif_claim_status)
      values (v_id, v_employers[1 + (i % array_length(v_employers, 1))], 'Employed',
              make_date(v_matric_year + 5, 2, 1), 177.12, 'Not Claiming');
      insert into saps_clearance_certificates (national_id_number, issue_date, status)
      values (v_id, current_date - 90, case when p.profile = 'record' then 'Record Found' else 'Clear' end);
      if p.profile = 'record' then
        insert into saps_criminal_records (case_number, national_id_number, offence_code, conviction_date, sentence_status)
        values (next_case_number(), v_id, case when i % 2 = 0 then 'FRAUD' else 'THEFT' end, current_date - 1500, 'Served');
      end if;
      if p.extra then
        insert into dha_passports (passport_number, national_id_number, issue_date, expiry_date, status)
        values (next_passport_number(), v_id, current_date - 700, current_date + 2950, 'Active');
      end if;

    elsif p.profile in ('srd', 'parent') then
      insert into labour_employment_records (national_id_number, employer_name, employment_status, start_date,
                                             uif_contribution_amount, uif_claim_status)
      values (v_id, null, 'Unemployed', current_date - 200, 0, 'Not Claiming');
      insert into sassa_grants (national_id_number, grant_type, status, payout_method)
      values (v_id, case when p.profile = 'srd' then 'SRD R370' else 'Child Support' end, 'Active',
              case when i % 2 = 0 then 'Bank Transfer' else 'Retail Post Office' end);
    end if;
  end loop;
end;
$$;
