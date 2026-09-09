-- dha_immigration_records
--
-- "Manage immigration information" (spec) -- visa/permit records for
-- non-citizens, same shape/RLS pattern as dha_passports. Distinct from
-- `citizens.citizenship_status` (citizen / permanent_resident / refugee /
-- visitor), which this table's `visa_type` tracks the detail behind.
--
-- APPLIED live via the Supabase MCP (migration `dha_immigration_records`).

create table public.dha_immigration_records (
  immigration_id uuid primary key default gen_random_uuid(),
  national_id_number text not null references public.citizens(id_number),
  visa_type text not null,
  status text not null check (status in ('Active','Expired','Revoked','Pending')),
  issue_date date not null,
  expiry_date date,
  created_at timestamptz not null default now()
);

alter table public.dha_immigration_records enable row level security;

create policy dha_immigration_records_select
  on public.dha_immigration_records for select to public
  using (is_admin() or current_official_department_code() = 'HOME_AFFAIRS' or national_id_number = current_citizen_id_number());

create policy dha_immigration_records_write
  on public.dha_immigration_records for all to authenticated
  using (is_admin() or current_official_department_code() = 'HOME_AFFAIRS')
  with check (is_admin() or current_official_department_code() = 'HOME_AFFAIRS');
