-- Fixes a live bug: next_passport_number / next_licence_number /
-- next_tax_number / next_matric_exam_number / next_property_reference each
-- pulled straight from a Postgres sequence that was seeded once (see
-- auto_generated_official_identifiers.sql) and never re-synced. When more
-- sample rows were added later directly against the tables (bypassing the
-- RPC), the sequences fell behind the real max in each table, so nextval()
-- started handing out numbers that already exist -> unique_violation /
-- "duplicate key" on insert. Matric was worst-drifted (sequence at 168,
-- 202 rows already existed), which is the "can't add a matric" bug -- but
-- passport (115 vs 133), licence (139 vs 176) and tax (116 vs 153) had the
-- same latent issue and would have hit it next.
--
-- Fix: make every sequence-backed generator self-healing, same
-- loop-until-unique pattern already used by generate_vin_number /
-- generate_registration_number / generate_sa_id_number / etc -- pull the
-- next sequence value, and if a row with that value already exists (stale
-- seed data), just keep pulling. nextval() is still atomic/race-safe
-- across concurrent officials; the existence check only ever matters for
-- values seeded before/outside the sequence, so this can never produce a
-- duplicate again regardless of how the tables get seeded in future.
--
-- Also fast-forwards each sequence to the live max now, so the fix is
-- immediate rather than relying on the loop to skip past ~30-40 stale
-- values on first call.
--
-- APPLIED live via the Supabase MCP (migration
-- `self_healing_official_identifiers`).

select setval('public.dha_passport_seq',
  (select max(substring(passport_number from 2)::bigint) from public.dha_passports where passport_number ~ '^A[0-9]+$'));
select setval('public.dot_licence_seq',
  (select max(licence_number::bigint) from public.dot_driver_licences where licence_number ~ '^[0-9]+$'));
select setval('public.sars_tax_seq',
  (select max(tax_number::bigint) from public.sars_taxpayers where tax_number ~ '^[0-9]+$'));
select setval('public.dbe_matric_seq',
  (select max(matric_exam_number::bigint) from public.dbe_nsc_results where matric_exam_number ~ '^[0-9]+$'));
select setval('public.dhs_property_seq',
  (select max(substring(property_reference from 6)::bigint) from public.properties where property_reference ~ '^PROP-[0-9]+$'));

create or replace function public.next_passport_number()
returns text language plpgsql as $$
declare
  v text;
begin
  loop
    v := 'A' || lpad(nextval('public.dha_passport_seq')::text, 8, '0');
    exit when not exists (select 1 from dha_passports where passport_number = v);
  end loop;
  return v;
end;
$$;

create or replace function public.next_licence_number()
returns text language plpgsql as $$
declare
  v text;
begin
  loop
    v := lpad(nextval('public.dot_licence_seq')::text, 10, '0');
    exit when not exists (select 1 from dot_driver_licences where licence_number = v);
  end loop;
  return v;
end;
$$;

create or replace function public.next_tax_number()
returns text language plpgsql as $$
declare
  v text;
begin
  loop
    v := lpad(nextval('public.sars_tax_seq')::text, 10, '0');
    exit when not exists (select 1 from sars_taxpayers where tax_number = v);
  end loop;
  return v;
end;
$$;

create or replace function public.next_case_number()
returns text language plpgsql as $$
declare
  v text;
begin
  loop
    v := 'CAS' || lpad(nextval('public.saps_case_seq')::text, 3, '0') || '/' ||
      to_char(current_date, 'MM') || '/' || to_char(current_date, 'YYYY');
    exit when not exists (select 1 from saps_criminal_records where case_number = v);
  end loop;
  return v;
end;
$$;

create or replace function public.next_matric_exam_number()
returns text language plpgsql as $$
declare
  v text;
begin
  loop
    v := nextval('public.dbe_matric_seq')::text;
    exit when not exists (select 1 from dbe_nsc_results where matric_exam_number = v);
  end loop;
  return v;
end;
$$;

create or replace function public.next_property_reference()
returns text language plpgsql as $$
declare
  v text;
begin
  loop
    v := 'PROP-' || lpad(nextval('public.dhs_property_seq')::text, 5, '0');
    exit when not exists (select 1 from properties where property_reference = v);
  end loop;
  return v;
end;
$$;
