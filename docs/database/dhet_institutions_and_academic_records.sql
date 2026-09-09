-- dhet_institutions + dhet_academic_records
--
-- "6 public universities... qualifications, academic records, TVET colleges"
-- (spec). `dhet_institutions` is a small reference table -- 6 universities +
-- 3 TVET colleges, seeded from the institution codes that were already
-- free-text in `dhet_student_enrollment` (UCT/UKZN/UP/WITS/NMU + 3 TVET
-- colleges), plus Stellenbosch University (SU) added to reach 6. A real FK
-- now ties `dhet_student_enrollment.institution_code` to this table.
--
-- `dhet_academic_records` is a separate, per-citizen transcript-style row
-- (qualification, year, final result) distinct from `dhet_student_enrollment`,
-- which only tracks live enrolment/completion status -- the two answer
-- different questions ("are they currently enrolled" vs "what did they
-- graduate with").
--
-- APPLIED live via the Supabase MCP (migration
-- `dhet_institutions_and_academic_records`).

create table public.dhet_institutions (
  institution_code text primary key,
  institution_name text not null,
  institution_type text not null check (institution_type in ('university','tvet')),
  created_at timestamptz not null default now()
);

insert into public.dhet_institutions (institution_code, institution_name, institution_type) values
  ('UCT','University of Cape Town','university'),
  ('UKZN','University of KwaZulu-Natal','university'),
  ('UP','University of Pretoria','university'),
  ('WITS','University of the Witwatersrand','university'),
  ('NMU','Nelson Mandela University','university'),
  ('SU','Stellenbosch University','university'),
  ('CPUT TVET','Cape Peninsula University of Technology TVET College','tvet'),
  ('False Bay TVET','False Bay TVET College','tvet'),
  ('Tshwane North TVET','Tshwane North TVET College','tvet');

alter table public.dhet_student_enrollment
  add constraint dhet_student_enrollment_institution_code_fkey
  foreign key (institution_code) references public.dhet_institutions(institution_code);

alter table public.dhet_institutions enable row level security;

create policy dhet_institutions_select
  on public.dhet_institutions for select to public
  using (auth.uid() is not null);

create policy dhet_institutions_write
  on public.dhet_institutions for all to authenticated
  using (is_admin() or current_official_department_code() = 'DHET')
  with check (is_admin() or current_official_department_code() = 'DHET');

create table public.dhet_academic_records (
  record_id uuid primary key default gen_random_uuid(),
  national_id_number text not null references public.citizens(id_number),
  institution_code text not null references public.dhet_institutions(institution_code),
  qualification_name text not null,
  year integer not null,
  final_result text not null,
  created_at timestamptz not null default now()
);

alter table public.dhet_academic_records enable row level security;

create policy dhet_academic_records_select
  on public.dhet_academic_records for select to public
  using (is_admin() or current_official_department_code() = 'DHET' or national_id_number = current_citizen_id_number());

create policy dhet_academic_records_write
  on public.dhet_academic_records for all to authenticated
  using (is_admin() or current_official_department_code() = 'DHET')
  with check (is_admin() or current_official_department_code() = 'DHET');
