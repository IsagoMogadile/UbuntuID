-- Officials must never type a passport number, driver's licence number,
-- VIN, tax number, SAPS case number, or matric exam number by hand -- these
-- are assigned by the issuing department, not chosen by the citizen or the
-- official. Real Postgres sequences (atomic/race-safe under concurrent
-- officials, unlike a max()+1 pattern) back a small set of "next
-- identifier" RPCs; `department_record_config.dart` no longer shows a text
-- field for any of these -- `DepartmentRepository`'s dedicated
-- issue*/update* methods (issuePassport, issueDriversLicence,
-- registerVehicle, registerTaxpayer, recordCriminalCase,
-- issueMatricCertificate) call the RPC and fill the value in.
--
-- Sequences start after the live max at the time this was applied (114
-- passports, 138 licences, 115 tax numbers, 62 SAPS cases, 164 matric exam
-- numbers) so a freshly generated identifier can never collide with
-- existing seed data.
--
-- VIN and number-plate aren't sequential in reality (unlike the others),
-- but are still department-assigned, not applicant-chosen -- random,
-- retried until unique against the live table instead of a sequence.
--
-- APPLIED live via the Supabase MCP (migration
-- `auto_generated_official_identifiers`).

create sequence public.dha_passport_seq start with 115;
create sequence public.dot_licence_seq start with 139;
create sequence public.sars_tax_seq start with 116;
create sequence public.saps_case_seq start with 63;
create sequence public.dbe_matric_seq start with 165;

create or replace function public.next_passport_number()
returns text language sql as $$
  select 'A' || lpad(nextval('public.dha_passport_seq')::text, 8, '0');
$$;

create or replace function public.next_licence_number()
returns text language sql as $$
  select lpad(nextval('public.dot_licence_seq')::text, 10, '0');
$$;

create or replace function public.next_tax_number()
returns text language sql as $$
  select lpad(nextval('public.sars_tax_seq')::text, 10, '0');
$$;

create or replace function public.next_case_number()
returns text language sql as $$
  select 'CAS' || lpad(nextval('public.saps_case_seq')::text, 3, '0') || '/' ||
    to_char(current_date, 'MM') || '/' || to_char(current_date, 'YYYY');
$$;

create or replace function public.next_matric_exam_number()
returns text language sql as $$
  select nextval('public.dbe_matric_seq')::text;
$$;

create or replace function public.generate_vin_number()
returns text language plpgsql as $$
declare
  v text;
begin
  loop
    v := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 17));
    exit when not exists (select 1 from dot_vehicles where vin_number = v);
  end loop;
  return v;
end;
$$;

create or replace function public.generate_registration_number()
returns text language plpgsql as $$
declare
  v text;
  provinces text[] := array['CA','GP','WC','KZN','EC','FS','MP','LP'];
begin
  loop
    v := provinces[1 + floor(random()*8)::int] || ' ' ||
      lpad(floor(random()*999)::text, 3, '0') || '-' || lpad(floor(random()*999)::text, 3, '0');
    exit when not exists (select 1 from dot_vehicles where registration_number = v);
  end loop;
  return v;
end;
$$;

grant execute on function public.next_passport_number() to authenticated;
grant execute on function public.next_licence_number() to authenticated;
grant execute on function public.next_tax_number() to authenticated;
grant execute on function public.next_case_number() to authenticated;
grant execute on function public.next_matric_exam_number() to authenticated;
grant execute on function public.generate_vin_number() to authenticated;
grant execute on function public.generate_registration_number() to authenticated;
