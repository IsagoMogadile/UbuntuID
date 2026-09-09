-- labour_employment_records
--
-- "Employment status (which organisation), UIF amounts and all that"
-- (spec) -- replaces the previous placeholder for Employment & Labour (a
-- generic `credentials` row against the `LABOUR_STATUS` credential type,
-- with no employer field at all -- see docs/FUTURE_WORK.md, which had
-- already flagged this as the one department with no dedicated table).
-- `DepartmentRepository.getLabourStatusRecords`/`insertLabourStatusRecord`
-- were removed; the "Employment / UIF" record type now goes through the
-- same generic `getRecordsByColumn`/`insertRecord`/`updateRecord` path
-- every other department table uses.
--
-- APPLIED live via the Supabase MCP (migration `labour_employment_records`).

create table public.labour_employment_records (
  record_id uuid primary key default gen_random_uuid(),
  national_id_number text not null references public.citizens(id_number),
  employer_name text,
  employment_status text not null check (employment_status in ('Employed','Unemployed','Self-Employed')),
  start_date date,
  end_date date,
  uif_contribution_amount numeric(10,2),
  uif_claim_status text check (uif_claim_status in ('Not Claiming','Claiming','Claim Approved','Claim Rejected')),
  created_at timestamptz not null default now()
);

alter table public.labour_employment_records enable row level security;

create policy labour_employment_records_select
  on public.labour_employment_records for select to public
  using (is_admin() or current_official_department_code() = 'LABOUR' or national_id_number = current_citizen_id_number());

create policy labour_employment_records_write
  on public.labour_employment_records for all to authenticated
  using (is_admin() or current_official_department_code() = 'LABOUR')
  with check (is_admin() or current_official_department_code() = 'LABOUR');
