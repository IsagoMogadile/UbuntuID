-- saps_wanted_persons
--
-- "Have a list of wanted people, if found indicate" (spec) -- a
-- department-wide list, not a per-citizen record, so it's read by a
-- dedicated screen (SapsWantedPersonsScreen) rather than the generic
-- RecordTypeConfig per-citizen record UI. Deliberately separate from
-- `saps_criminal_records` ("list of offenders and type of offense", read by
-- SapsOffendersScreen, no new table needed there) -- being wanted and being
-- a convicted offender are different facts that can exist independently.
--
-- APPLIED live via the Supabase MCP (migration `saps_wanted_persons`).

create table public.saps_wanted_persons (
  wanted_id uuid primary key default gen_random_uuid(),
  national_id_number text not null references public.citizens(id_number),
  reason text not null,
  date_listed date not null default current_date,
  status text not null default 'Wanted' check (status in ('Wanted','Apprehended','Cleared')),
  apprehended_date date,
  created_at timestamptz not null default now()
);

alter table public.saps_wanted_persons enable row level security;

create policy saps_wanted_persons_select
  on public.saps_wanted_persons for select to public
  using (is_admin() or current_official_department_code() = 'SAPS' or national_id_number = current_citizen_id_number());

create policy saps_wanted_persons_write
  on public.saps_wanted_persons for all to authenticated
  using (is_admin() or current_official_department_code() = 'SAPS')
  with check (is_admin() or current_official_department_code() = 'SAPS');
