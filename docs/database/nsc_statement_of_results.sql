-- nsc_statement_of_results
--
-- National Senior Certificate Statements of Results: examination results
-- synchronisation, automated achievement levels and provisional pass
-- categories, controlled publication, and the citizen's own statement.
--
-- How it connects to what already exists
-- --------------------------------------
-- * dbe_nsc_results (one row per certificate, keyed by matric_exam_number)
--   is left as it is. A statement links to it by examination number; when
--   no certificate exists yet, publication creates one using the same
--   columns the Department Official "Matric Certificate" form writes.
-- * dbe_exam_results_source stands in for the external DBE examination
--   system. It is seeded below with fictional marks for existing learners,
--   and is kept apart from UbuntuID's own records so an authorised DBE API
--   can replace it later without touching anything else.
-- * dbe_nsc_statements / dbe_nsc_statement_subjects hold what UbuntuID has
--   synchronised and calculated. Only DBE officials and administrators can
--   read them. Citizens never read these tables: they get their own
--   *published* snapshot through my_nsc_statements(), so unpublished marks
--   and later unreviewed changes stay private.
-- * Synchronisation, publication and review run as security-definer
--   functions that check the caller is an active DBE official, so marks
--   and pass categories can't be written or edited from the app.
-- * Audit entries go to audit_logs and notifications to notifications,
--   the same way citizen_feedback.sql does.
--
-- Pass categories (nsc_evaluate) follow the DBE NSC promotion requirements
-- and higher-education admission minimums for the standard seven-subject
-- pathway (2008 onwards). Anything outside that pathway -- missing or
-- unknown subjects, more than seven subjects, invalid marks, years before
-- 2008 -- is flagged for review rather than guessed. The calculated
-- category is provisional: it must match the official outcome supplied by
-- the source before a record can be published.
--
-- Safe to re-run. Nothing existing is deleted or overwritten.
-- NOT YET APPLIED -- run in the Supabase SQL editor.

-- ---------------------------------------------------------------------------
-- 1. Subject catalogue (reference data for the calculation)
-- ---------------------------------------------------------------------------

create table if not exists public.dbe_nsc_subject_catalogue (
  subject_name  text primary key,
  subject_group text not null check (subject_group in (
                  'home_language', 'first_additional_language', 'mathematics',
                  'life_orientation', 'elective')),
  -- On the higher-education "designated subjects" list used for Bachelor's
  -- admission.
  designated    boolean not null default false,
  -- Set for language subjects, e.g. 'English'.
  language      text
);

alter table public.dbe_nsc_subject_catalogue enable row level security;
drop policy if exists dbe_nsc_subject_catalogue_select on public.dbe_nsc_subject_catalogue;
create policy dbe_nsc_subject_catalogue_select on public.dbe_nsc_subject_catalogue
  for select to authenticated using (true);

insert into public.dbe_nsc_subject_catalogue (subject_name, subject_group, designated, language)
select lang || ' Home Language', 'home_language', true, lang
from unnest(array['Afrikaans', 'English', 'isiNdebele', 'isiXhosa', 'isiZulu', 'Sepedi', 'Sesotho',
                  'Setswana', 'siSwati', 'Tshivenda', 'Xitsonga']) as lang
union all
select lang || ' First Additional Language', 'first_additional_language', true, lang
from unnest(array['Afrikaans', 'English', 'isiNdebele', 'isiXhosa', 'isiZulu', 'Sepedi', 'Sesotho',
                  'Setswana', 'siSwati', 'Tshivenda', 'Xitsonga']) as lang
union all
select * from (values
  ('Mathematics', 'mathematics', true, null::text),
  ('Mathematical Literacy', 'mathematics', true, null),
  ('Technical Mathematics', 'mathematics', false, null),
  ('Life Orientation', 'life_orientation', false, null),
  ('Accounting', 'elective', true, null),
  ('Agricultural Sciences', 'elective', true, null),
  ('Business Studies', 'elective', true, null),
  ('Consumer Studies', 'elective', true, null),
  ('Dramatic Arts', 'elective', true, null),
  ('Economics', 'elective', true, null),
  ('Engineering Graphics and Design', 'elective', true, null),
  ('Geography', 'elective', true, null),
  ('History', 'elective', true, null),
  ('Information Technology', 'elective', true, null),
  ('Life Sciences', 'elective', true, null),
  ('Music', 'elective', true, null),
  ('Physical Sciences', 'elective', true, null),
  ('Religion Studies', 'elective', true, null),
  ('Visual Arts', 'elective', true, null),
  ('Agricultural Management Practices', 'elective', false, null),
  ('Agricultural Technology', 'elective', false, null),
  ('Civil Technology', 'elective', false, null),
  ('Computer Applications Technology', 'elective', false, null),
  ('Dance Studies', 'elective', false, null),
  ('Design', 'elective', false, null),
  ('Electrical Technology', 'elective', false, null),
  ('Hospitality Studies', 'elective', false, null),
  ('Marine Sciences', 'elective', false, null),
  ('Mechanical Technology', 'elective', false, null),
  ('Technical Sciences', 'elective', false, null),
  ('Tourism', 'elective', false, null)
) as v(subject_name, subject_group, designated, language)
on conflict (subject_name) do nothing;

-- ---------------------------------------------------------------------------
-- 2. Tables
-- ---------------------------------------------------------------------------

-- The external examination system (simulated). `subjects` is a JSON array
-- of {"subject": "...", "percentage": 72}.
create table if not exists public.dbe_exam_results_source (
  source_record_id       uuid primary key default gen_random_uuid(),
  exam_number            text not null,
  exam_year              int  not null,
  exam_session           text,
  national_id_number     text,
  first_name             text,
  last_name              text,
  school_name            text,
  subjects               jsonb not null default '[]'::jsonb,
  official_pass_category text,
  updated_at             timestamptz not null default now(),
  unique (exam_number, exam_year)
);

create table if not exists public.dbe_nsc_statements (
  statement_id              uuid primary key default gen_random_uuid(),
  exam_number               text not null,
  exam_year                 int  not null,
  -- dbe_nsc_results row this statement belongs to (null until matched or
  -- created on publication).
  matric_exam_number        text,
  citizen_id                uuid references public.citizens (citizen_id) on delete set null,
  national_id_number        text,
  learner_name              text,
  school_name               text,
  exam_session              text,
  calculated_pass_category  text,
  official_pass_category    text,
  -- Requirement-by-requirement explanation from nsc_evaluate().
  evaluation                jsonb,
  publication_status        text not null default 'unpublished'
                            check (publication_status in ('unpublished', 'published', 'requires_review')),
  review_reasons            text[] not null default '{}',
  changed_after_publication boolean not null default false,
  record_reference          text not null,
  source_hash               text,
  first_synced_at           timestamptz not null default now(),
  last_synced_at            timestamptz not null default now(),
  published_at              timestamptz,
  published_by              uuid,
  -- What the citizen sees: frozen at publication, so later unreviewed
  -- changes never reach them.
  published_snapshot        jsonb,
  notified_at               timestamptz,
  unique (exam_number, exam_year)
);

create index if not exists dbe_nsc_statements_citizen_idx on public.dbe_nsc_statements (citizen_id);
create index if not exists dbe_nsc_statements_status_idx on public.dbe_nsc_statements (publication_status);

create table if not exists public.dbe_nsc_statement_subjects (
  statement_id      uuid not null references public.dbe_nsc_statements (statement_id) on delete cascade,
  subject_name      text not null,
  subject_group     text,
  percentage        numeric(5, 2),
  achievement_level smallint,
  sort_order        int not null default 0,
  primary key (statement_id, subject_name)
);

create table if not exists public.dbe_results_sync_runs (
  run_id                   uuid primary key default gen_random_uuid(),
  started_at               timestamptz not null default now(),
  finished_at              timestamptz,
  status                   text not null default 'running' check (status in ('running', 'completed', 'failed')),
  run_by                   uuid,
  source_name              text,
  records_received         int not null default 0,
  records_imported         int not null default 0,
  records_updated          int not null default 0,
  records_unchanged        int not null default 0,
  records_requiring_review int not null default 0,
  error_message            text
);

-- Read access: DBE officials and administrators only. No write policies --
-- every write goes through the functions below.
do $$
declare
  t text;
begin
  foreach t in array array['dbe_exam_results_source', 'dbe_nsc_statements', 'dbe_nsc_statement_subjects',
                           'dbe_results_sync_runs']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_select', t);
    execute format(
      'create policy %I on public.%I for select to authenticated '
      'using ((select is_admin()) or (select current_official_department_code()) = ''DBE'')',
      t || '_select', t);
  end loop;
end;
$$;

-- New certificates created on publication may carry 'NSC Pass' or
-- 'NSC Not Achieved'. If overall_pass_status has a check constraint listing
-- the old three values, widen it (NOT VALID: existing rows aren't rechecked).
do $$
declare
  c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.dbe_nsc_results'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%overall_pass_status%'
  loop
    execute format('alter table public.dbe_nsc_results drop constraint %I', c.conname);
  end loop;
  if not exists (select 1 from pg_constraint
                 where conrelid = 'public.dbe_nsc_results'::regclass and conname = 'dbe_nsc_results_pass_status_check') then
    alter table public.dbe_nsc_results add constraint dbe_nsc_results_pass_status_check
      check (overall_pass_status in ('Bachelor Pass', 'Diploma', 'Higher Certificate', 'NSC Pass', 'NSC Not Achieved'))
      not valid;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Calculation (pure, reusable, testable -- see nsc_results_tests.sql)
-- ---------------------------------------------------------------------------

-- NSC seven-point achievement scale.
create or replace function public.nsc_achievement_level(p_percentage numeric)
returns smallint
language sql
immutable
as $$
  select case
    when p_percentage is null or p_percentage < 0 or p_percentage > 100 then null
    when p_percentage >= 80 then 7
    when p_percentage >= 70 then 6
    when p_percentage >= 60 then 5
    when p_percentage >= 50 then 4
    when p_percentage >= 40 then 3
    when p_percentage >= 30 then 2
    else 1
  end::smallint;
$$;

-- Maps the wording different sources use onto UbuntuID's five categories.
create or replace function public.nsc_normalise_category(p_category text)
returns text
language sql
immutable
as $$
  select case
    when p_category is null or trim(p_category) = '' then null
    when lower(replace(trim(p_category), '''', '')) in ('bachelor pass', 'bachelors pass', 'bachelor', 'bachelors')
      then 'Bachelor''s Pass'
    when lower(trim(p_category)) in ('diploma', 'diploma pass') then 'Diploma Pass'
    when lower(trim(p_category)) in ('higher certificate', 'higher certificate pass') then 'Higher Certificate Pass'
    when lower(trim(p_category)) in ('nsc', 'nsc pass', 'pass') then 'NSC Pass'
    when lower(trim(p_category)) in ('nsc not achieved', 'not achieved', 'fail', 'failed') then 'NSC Not Achieved'
    else trim(p_category)
  end;
$$;

-- The wording dbe_nsc_results.overall_pass_status already uses.
create or replace function public.nsc_certificate_label(p_category text)
returns text
language sql
immutable
as $$
  select case nsc_normalise_category(p_category)
    when 'Bachelor''s Pass' then 'Bachelor Pass'
    when 'Diploma Pass' then 'Diploma'
    when 'Higher Certificate Pass' then 'Higher Certificate'
    else nsc_normalise_category(p_category)
  end;
$$;

-- Evaluates one learner's results.
--   p_subjects: [{"subject": "English Home Language", "percentage": 72}, ...]
-- Returns {
--   "category":       highest category met, or null when the record needs review,
--   "review_reasons": [plain-English reasons the record can't be evaluated],
--   "subjects":       [{subject, percentage, achievement_level, subject_group}],
--   "checks":         [{requirement, met}] -- why the category was reached
-- }
--
-- Rules (standard seven-subject pathway, 2008 onwards):
--   NSC achieved:   Home Language >= 40%; of the other six subjects, at least
--                   two >= 40% and at least five >= 30% (one may be lower).
--   Language of learning (English or Afrikaans, Home or First Additional
--                   Language) >= 30% is needed for every higher-education
--                   category; without it an achieved NSC is an "NSC Pass".
--   Higher Certificate: NSC achieved + language of learning.
--   Diploma:        + at least three other subjects >= 40% (excluding Home
--                   Language and Life Orientation).
--   Bachelor's:     + at least four other designated subjects >= 50%
--                   (excluding Home Language and Life Orientation).
-- Evaluated from the highest category down, never from an average.
create or replace function public.nsc_evaluate(p_exam_year int, p_subjects jsonb)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  v_reasons   text[] := '{}';
  v_rows      jsonb := '[]'::jsonb;
  v_checks    jsonb := '[]'::jsonb;
  r           record;
  v_count     int;
  v_distinct  int;
  v_hl        numeric;
  v_hl_lang   text;
  v_fal_lang  text;
  n_hl        int := 0;
  n_fal       int := 0;
  n_math      int := 0;
  n_lo        int := 0;
  n_elective  int := 0;
  v_others    numeric[] := '{}';
  v_sorted    numeric[];
  v_lolt      numeric;
  n_bachelor  int := 0;
  n_diploma   int := 0;
  v_nsc       boolean;
  v_category  text;
begin
  if p_subjects is null or jsonb_typeof(p_subjects) <> 'array' or jsonb_array_length(p_subjects) = 0 then
    return jsonb_build_object(
      'category', null,
      'review_reasons', jsonb_build_array('No subject results were supplied.'),
      'subjects', '[]'::jsonb,
      'checks', '[]'::jsonb);
  end if;

  if p_exam_year is null or p_exam_year < 2008 or p_exam_year > extract(year from now())::int then
    v_reasons := v_reasons || format(
      'The examination year (%s) falls outside the National Senior Certificate rules UbuntuID applies (2008 onwards).',
      coalesce(p_exam_year::text, 'not supplied'));
  end if;

  select count(*), count(distinct lower(trim(item ->> 'subject')))
    into v_count, v_distinct
  from jsonb_array_elements(p_subjects) as t(item);

  if v_distinct < v_count then
    v_reasons := v_reasons || 'The same subject appears more than once.'::text;
  end if;

  for r in
    select trim(t.item ->> 'subject') as subject,
           case when (t.item ->> 'percentage') ~ '^\s*\d+(\.\d+)?\s*$'
                then (t.item ->> 'percentage')::numeric end as pct,
           c.subject_group, c.designated, c.language, t.ord
    from jsonb_array_elements(p_subjects) with ordinality as t(item, ord)
    left join dbe_nsc_subject_catalogue c on lower(c.subject_name) = lower(trim(t.item ->> 'subject'))
    order by t.ord
  loop
    if r.subject_group is null then
      v_reasons := v_reasons || format('"%s" is not a recognised National Senior Certificate subject.',
                                       coalesce(nullif(r.subject, ''), 'Unnamed subject'));
    end if;
    if r.pct is null or r.pct > 100 then
      v_reasons := v_reasons || format('The mark for %s is missing or invalid.', coalesce(nullif(r.subject, ''), 'a subject'));
    end if;

    v_rows := v_rows || jsonb_build_object(
      'subject', r.subject,
      'percentage', r.pct,
      'achievement_level', nsc_achievement_level(r.pct),
      'subject_group', r.subject_group);

    case r.subject_group
      when 'home_language' then
        n_hl := n_hl + 1; v_hl := r.pct; v_hl_lang := r.language;
      when 'first_additional_language' then
        n_fal := n_fal + 1; v_fal_lang := r.language;
      when 'mathematics' then n_math := n_math + 1;
      when 'life_orientation' then n_lo := n_lo + 1;
      when 'elective' then n_elective := n_elective + 1;
      else null;
    end case;

    if r.subject_group is distinct from 'home_language' then
      v_others := v_others || coalesce(r.pct, 0);
      if r.subject_group is distinct from 'life_orientation' and r.pct is not null then
        if r.pct >= 50 and r.designated then n_bachelor := n_bachelor + 1; end if;
        if r.pct >= 40 then n_diploma := n_diploma + 1; end if;
      end if;
    end if;

    if r.language in ('English', 'Afrikaans') and r.pct is not null then
      v_lolt := greatest(coalesce(v_lolt, 0), r.pct);
    end if;
  end loop;

  if v_count < 7 then
    v_reasons := v_reasons || format(
      'The record is incomplete: %s of the seven required subjects were supplied.', v_count);
  elsif v_count > 7 then
    v_reasons := v_reasons || format(
      '%s subjects were supplied; results with more than seven subjects need a manual evaluation.', v_count);
  elsif not (n_hl = 1 and n_fal = 1 and n_math = 1 and n_lo = 1 and n_elective = 3) then
    v_reasons := v_reasons || ('The subject combination does not follow the standard NSC pathway: one Home Language, '
      || 'one First Additional Language, Mathematics or Mathematical Literacy, Life Orientation and three other subjects.');
  end if;

  if n_hl = 1 and n_fal = 1 and v_hl_lang = v_fal_lang then
    v_reasons := v_reasons || 'The Home Language and First Additional Language must be different languages.'::text;
  end if;

  if cardinality(v_reasons) > 0 then
    return jsonb_build_object('category', null, 'review_reasons', to_jsonb(v_reasons),
                              'subjects', v_rows, 'checks', '[]'::jsonb);
  end if;

  select array_agg(x order by x desc) into v_sorted from unnest(v_others) as x;
  v_nsc := v_hl >= 40 and v_sorted[2] >= 40 and v_sorted[5] >= 30;

  v_checks := jsonb_build_array(
    jsonb_build_object('requirement', 'Home Language at 40% or more', 'met', v_hl >= 40),
    jsonb_build_object('requirement', 'Two other subjects at 40% or more', 'met', v_sorted[2] >= 40),
    jsonb_build_object('requirement', 'Five other subjects at 30% or more (one subject may be lower)',
                       'met', v_sorted[5] >= 30),
    jsonb_build_object('requirement', 'English or Afrikaans (language of learning) at 30% or more',
                       'met', coalesce(v_lolt, 0) >= 30),
    jsonb_build_object('requirement', 'Diploma: three other subjects at 40% or more, excluding Life Orientation',
                       'met', n_diploma >= 3),
    jsonb_build_object('requirement', 'Bachelor''s: four other designated subjects at 50% or more, excluding Life Orientation',
                       'met', n_bachelor >= 4));

  v_category := case
    when not v_nsc then 'NSC Not Achieved'
    when coalesce(v_lolt, 0) < 30 then 'NSC Pass'
    when n_bachelor >= 4 then 'Bachelor''s Pass'
    when n_diploma >= 3 then 'Diploma Pass'
    else 'Higher Certificate Pass'
  end;

  return jsonb_build_object('category', v_category, 'review_reasons', '[]'::jsonb,
                            'subjects', v_rows, 'checks', v_checks);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Synchronisation, publication and review (DBE officials only)
-- ---------------------------------------------------------------------------

-- The calling active DBE official's official_id, or an error.
create or replace function public.nsc_require_dbe_official()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_official_id uuid;
begin
  select o.official_id into v_official_id
  from department_officials o
  join departments d on d.department_id = o.department_id
  where o.auth_user_id = auth.uid() and o.active and d.department_code = 'DBE';
  if v_official_id is null then
    raise exception 'Only Department of Basic Education officials can manage examination results.';
  end if;
  return v_official_id;
end;
$$;

create or replace function public.sync_nsc_results()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_official_id   uuid := nsc_require_dbe_official();
  v_run_id        uuid;
  s               record;
  v_eval          jsonb;
  v_reasons       text[];
  v_calc          text;
  v_official_cat  text;
  v_citizen_id    uuid;
  v_citizen_last  text;
  v_matches       int;
  v_link          text;
  v_link_id       text;
  v_link_year     int;
  v_existing_cat  text;
  v_hash          text;
  v_existing      dbe_nsc_statements%rowtype;
  v_found         boolean;
  v_status        text;
  v_changed_pub   boolean;
  v_statement_id  uuid;
  v_name          text;
  n_received      int := 0;
  n_imported      int := 0;
  n_updated       int := 0;
  n_unchanged     int := 0;
  n_review        int := 0;
begin
  insert into dbe_results_sync_runs (run_by, source_name)
  values (v_official_id, 'UbuntuID examination results source')
  returning run_id into v_run_id;

  begin
    for s in select * from dbe_exam_results_source order by exam_year, exam_number loop
      n_received := n_received + 1;
      v_eval := nsc_evaluate(s.exam_year, s.subjects);
      v_reasons := array(select jsonb_array_elements_text(v_eval -> 'review_reasons'));
      v_calc := v_eval ->> 'category';
      v_official_cat := nsc_normalise_category(s.official_pass_category);
      v_name := nullif(trim(concat_ws(' ', s.first_name, s.last_name)), '');

      -- Citizen: by identity number only, never by name.
      v_citizen_id := null;
      v_citizen_last := null;
      if nullif(trim(s.national_id_number), '') is null then
        v_reasons := v_reasons || 'No identity number was supplied, so the learner could not be matched to a citizen.'::text;
      else
        select count(*) into v_matches from citizens where id_number = trim(s.national_id_number);
        if v_matches = 0 then
          v_reasons := v_reasons || 'Citizen matching unsuccessful: no UbuntuID citizen holds this identity number.'::text;
        elsif v_matches > 1 then
          v_reasons := v_reasons || 'Citizen matching is ambiguous: more than one citizen holds this identity number.'::text;
        else
          select citizen_id, last_name into v_citizen_id, v_citizen_last
          from citizens where id_number = trim(s.national_id_number);
          if nullif(trim(s.last_name), '') is not null
             and lower(trim(s.last_name)) is distinct from lower(trim(v_citizen_last)) then
            v_reasons := v_reasons || 'The surname in the examination record does not match the citizen''s record.'::text;
          end if;
        end if;
      end if;

      -- Existing certificate: by examination number, checked against the
      -- learner's identity number and examination year.
      v_link := null;
      v_existing_cat := null;
      select matric_exam_number, national_id_number, year, overall_pass_status
        into v_link, v_link_id, v_link_year, v_existing_cat
      from dbe_nsc_results where matric_exam_number = s.exam_number;
      if v_link is not null then
        if v_link_id is distinct from trim(s.national_id_number) then
          v_reasons := v_reasons || 'This examination number already belongs to a different learner''s certificate.'::text;
          v_link := null;
          v_existing_cat := null;
        elsif v_link_year is distinct from s.exam_year then
          v_reasons := v_reasons || format(
            'The existing certificate with this examination number records %s as the examination year, not %s.',
            v_link_year, s.exam_year);
        end if;
      elsif exists (select 1 from dbe_nsc_results
                    where national_id_number = trim(s.national_id_number) and year = s.exam_year) then
        v_reasons := v_reasons
          || 'An existing certificate for this learner and year has a different examination number.'::text;
      end if;

      -- Validate the calculated category against the official outcome.
      if v_calc is not null then
        if v_official_cat is null then
          v_reasons := v_reasons
            || 'No official outcome was supplied, so the calculated pass category cannot be validated yet.'::text;
        elsif v_official_cat <> v_calc then
          v_reasons := v_reasons || format(
            'Discrepancy: UbuntuID calculated a %s, but the official outcome is a %s.', v_calc, v_official_cat);
        end if;
      end if;
      if v_existing_cat is not null
         and nsc_normalise_category(v_existing_cat) is distinct from coalesce(v_official_cat, v_calc) then
        v_reasons := v_reasons || format(
          'The existing certificate records "%s", which differs from the examination outcome.', v_existing_cat);
      end if;

      -- What decides whether a record changed. The certificate link is left
      -- out: publication itself creates certificates, which isn't a change.
      v_hash := md5(concat_ws('|', s.subjects::text, s.official_pass_category, s.national_id_number,
                              s.first_name, s.last_name, s.school_name, s.exam_session,
                              v_citizen_id::text, array_to_string(v_reasons, ';')));

      select * into v_existing from dbe_nsc_statements
      where exam_number = s.exam_number and exam_year = s.exam_year;
      v_found := found;

      if v_found and v_existing.source_hash = v_hash then
        n_unchanged := n_unchanged + 1;
        update dbe_nsc_statements
           set last_synced_at = now(), matric_exam_number = coalesce(matric_exam_number, v_link)
         where statement_id = v_existing.statement_id;
        continue;
      end if;

      v_changed_pub := v_found and v_existing.published_at is not null;
      if v_changed_pub then
        v_reasons := v_reasons
          || 'The results changed after they were published. Review them before publishing the update.'::text;
      end if;
      v_status := case when cardinality(v_reasons) > 0 then 'requires_review' else 'unpublished' end;

      if not v_found then
        insert into dbe_nsc_statements (
          exam_number, exam_year, matric_exam_number, citizen_id, national_id_number, learner_name,
          school_name, exam_session, calculated_pass_category, official_pass_category, evaluation,
          publication_status, review_reasons, record_reference, source_hash)
        values (
          s.exam_number, s.exam_year, v_link, v_citizen_id, trim(s.national_id_number), v_name,
          s.school_name, s.exam_session, v_calc, v_official_cat, v_eval,
          v_status, v_reasons, 'NSC-' || s.exam_year || '-' || s.exam_number, v_hash)
        returning statement_id into v_statement_id;
        n_imported := n_imported + 1;
      else
        v_statement_id := v_existing.statement_id;
        update dbe_nsc_statements set
          matric_exam_number = coalesce(v_link, matric_exam_number),
          citizen_id = v_citizen_id,
          national_id_number = trim(s.national_id_number),
          learner_name = v_name,
          school_name = s.school_name,
          exam_session = s.exam_session,
          calculated_pass_category = v_calc,
          official_pass_category = v_official_cat,
          evaluation = v_eval,
          publication_status = v_status,
          review_reasons = v_reasons,
          changed_after_publication = v_changed_pub,
          source_hash = v_hash,
          last_synced_at = now()
        where statement_id = v_statement_id;
        delete from dbe_nsc_statement_subjects where statement_id = v_statement_id;
        n_updated := n_updated + 1;
      end if;

      insert into dbe_nsc_statement_subjects (statement_id, subject_name, subject_group, percentage,
                                              achievement_level, sort_order)
      select v_statement_id, x.item ->> 'subject', x.item ->> 'subject_group',
             (x.item ->> 'percentage')::numeric, (x.item ->> 'achievement_level')::smallint, x.ord
      from jsonb_array_elements(v_eval -> 'subjects') with ordinality as x(item, ord)
      where nullif(x.item ->> 'subject', '') is not null
      on conflict do nothing;

      insert into audit_logs (action, actor_id, actor_type, related_id, related_table, target_citizen_id, metadata)
      values (case when v_found then 'nsc_record_updated' else 'nsc_record_imported' end,
              v_official_id, 'department_official', v_statement_id, 'dbe_nsc_statements', v_citizen_id,
              jsonb_build_object('exam_number', s.exam_number, 'exam_year', s.exam_year,
                                 'calculated_pass_category', v_calc));

      if exists (select 1 from unnest(v_reasons) as m where m like 'Discrepancy:%') then
        insert into audit_logs (action, actor_id, actor_type, related_id, related_table, target_citizen_id, metadata)
        values ('nsc_discrepancy_identified', v_official_id, 'department_official', v_statement_id,
                'dbe_nsc_statements', v_citizen_id,
                jsonb_build_object('exam_number', s.exam_number, 'calculated_pass_category', v_calc,
                                   'official_pass_category', v_official_cat));
      end if;
      if v_status = 'requires_review' then
        insert into audit_logs (action, actor_id, actor_type, related_id, related_table, target_citizen_id, metadata)
        values ('nsc_record_requires_review', v_official_id, 'department_official', v_statement_id,
                'dbe_nsc_statements', v_citizen_id,
                jsonb_build_object('exam_number', s.exam_number, 'reasons', to_jsonb(v_reasons)));
      end if;
    end loop;

    select count(*) into n_review from dbe_nsc_statements where publication_status = 'requires_review';

    update dbe_results_sync_runs set
      finished_at = now(), status = 'completed',
      records_received = n_received, records_imported = n_imported, records_updated = n_updated,
      records_unchanged = n_unchanged, records_requiring_review = n_review
    where run_id = v_run_id;

    insert into audit_logs (action, actor_id, actor_type, related_id, related_table, metadata)
    values ('nsc_results_synchronised', v_official_id, 'department_official', v_run_id, 'dbe_results_sync_runs',
            jsonb_build_object('received', n_received, 'imported', n_imported, 'updated', n_updated,
                               'unchanged', n_unchanged, 'requiring_review', n_review));
  exception when others then
    -- Everything inside this block is rolled back; the run itself is kept
    -- as a failed run.
    update dbe_results_sync_runs set finished_at = now(), status = 'failed', error_message = sqlerrm
    where run_id = v_run_id;
    insert into audit_logs (action, actor_id, actor_type, related_id, related_table, metadata)
    values ('nsc_sync_failed', v_official_id, 'department_official', v_run_id, 'dbe_results_sync_runs',
            jsonb_build_object('error', sqlerrm));
    return jsonb_build_object('status', 'failed');
  end;

  return jsonb_build_object('status', 'completed', 'received', n_received, 'imported', n_imported,
                            'updated', n_updated, 'unchanged', n_unchanged, 'requiring_review', n_review);
end;
$$;

-- Publishes the given statements (or every eligible one when null). Each is
-- re-checked here; ineligible ones are skipped, never forced through.
create or replace function public.publish_nsc_results(p_statement_ids uuid[] default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_official_id  uuid := nsc_require_dbe_official();
  st             dbe_nsc_statements%rowtype;
  v_snapshot     jsonb;
  v_type_id      uuid;
  v_dept_id      uuid;
  v_republish    boolean;
  n_published    int := 0;
  n_skipped      int := 0;
begin
  select credential_type_id, issuing_department_id into v_type_id, v_dept_id
  from credential_types where type_code = 'NSC';

  for st in
    select * from dbe_nsc_statements
    where publication_status = 'unpublished'
      and (p_statement_ids is null or statement_id = any (p_statement_ids))
    for update
  loop
    if st.citizen_id is null
       or st.calculated_pass_category is null
       or st.official_pass_category is distinct from st.calculated_pass_category
       or cardinality(st.review_reasons) > 0
       or not exists (select 1 from dbe_nsc_statement_subjects where statement_id = st.statement_id) then
      n_skipped := n_skipped + 1;
      continue;
    end if;

    -- Link a certificate recorded since the last synchronisation, if it's
    -- the same learner and year; anything else is a conflict to skip.
    if st.matric_exam_number is null
       and exists (select 1 from dbe_nsc_results where matric_exam_number = st.exam_number) then
      if exists (select 1 from dbe_nsc_results
                 where matric_exam_number = st.exam_number
                   and national_id_number = st.national_id_number and year = st.exam_year) then
        st.matric_exam_number := st.exam_number;
      else
        n_skipped := n_skipped + 1;
        continue;
      end if;
    end if;

    -- No certificate yet: create it with the existing columns.
    if st.matric_exam_number is null then
      insert into dbe_nsc_results (matric_exam_number, national_id_number, year, overall_pass_status)
      values (st.exam_number, st.national_id_number, st.exam_year, nsc_certificate_label(st.official_pass_category));
      st.matric_exam_number := st.exam_number;

      if st.official_pass_category <> 'NSC Not Achieved' and v_type_id is not null
         and not exists (select 1 from credentials where citizen_id = st.citizen_id and credential_type_id = v_type_id) then
        insert into credentials (citizen_id, credential_type_id, issuing_department_id, status, issued_date)
        values (st.citizen_id, v_type_id, v_dept_id, 'active', current_date);
      end if;
    end if;

    v_snapshot := jsonb_build_object(
      'statement_id', st.statement_id,
      'matric_exam_number', st.matric_exam_number,
      'exam_number', st.exam_number,
      'exam_year', st.exam_year,
      'exam_session', st.exam_session,
      'school_name', st.school_name,
      'learner_name', st.learner_name,
      'pass_category', st.official_pass_category,
      'record_reference', st.record_reference,
      'published_at', now(),
      'subjects', (select jsonb_agg(jsonb_build_object(
                     'subject', subject_name, 'percentage', percentage,
                     'achievement_level', achievement_level) order by sort_order)
                   from dbe_nsc_statement_subjects where statement_id = st.statement_id));

    v_republish := st.published_snapshot is not null;

    update dbe_nsc_statements set
      publication_status = 'published',
      matric_exam_number = st.matric_exam_number,
      published_at = now(),
      published_by = v_official_id,
      published_snapshot = v_snapshot,
      changed_after_publication = false
    where statement_id = st.statement_id;

    -- One notification per publication; none if the published results are
    -- unchanged since the last one.
    if st.notified_at is null
       or (st.published_snapshot -> 'subjects') is distinct from (v_snapshot -> 'subjects')
       or (st.published_snapshot ->> 'pass_category') is distinct from (v_snapshot ->> 'pass_category') then
      insert into notifications (citizen_id, message, channel, delivery_status)
      values (st.citizen_id,
              case when v_republish
                then 'Updated Examination Results Available: Your National Senior Certificate examination results '
                     || 'have been updated. Visit Government Services to view your Statement of Results.'
                else 'Examination Results Available: Your National Senior Certificate examination results are now '
                     || 'available. Visit Government Services to view your Statement of Results.'
              end,
              'in_app', 'sent');
      update dbe_nsc_statements set notified_at = now() where statement_id = st.statement_id;
    end if;

    insert into audit_logs (action, actor_id, actor_type, related_id, related_table, target_citizen_id, metadata)
    values ('nsc_results_published', v_official_id, 'department_official', st.statement_id, 'dbe_nsc_statements',
            st.citizen_id, jsonb_build_object('exam_number', st.exam_number, 'exam_year', st.exam_year,
                                              'pass_category', st.official_pass_category));
    n_published := n_published + 1;
  end loop;

  return jsonb_build_object('published', n_published, 'skipped', n_skipped);
end;
$$;

-- Confirms an official has reviewed results that changed after publication.
-- Only clears that one flag; any other reason still has to be resolved at
-- the source and re-synchronised.
create or replace function public.confirm_nsc_statement_review(p_statement_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_official_id uuid := nsc_require_dbe_official();
  st            dbe_nsc_statements%rowtype;
  v_reasons     text[];
begin
  select * into st from dbe_nsc_statements where statement_id = p_statement_id for update;
  if not found then
    raise exception 'Examination record not found.';
  end if;
  if not st.changed_after_publication then
    raise exception 'This record has no published changes awaiting review.';
  end if;

  v_reasons := array(select m from unnest(st.review_reasons) as m where m not like 'The results changed after%');
  update dbe_nsc_statements set
    changed_after_publication = false,
    review_reasons = v_reasons,
    publication_status = case when cardinality(v_reasons) > 0 then 'requires_review' else 'unpublished' end
  where statement_id = p_statement_id;

  insert into audit_logs (action, actor_id, actor_type, related_id, related_table, target_citizen_id, metadata)
  values ('nsc_record_reviewed', v_official_id, 'department_official', p_statement_id, 'dbe_nsc_statements',
          st.citizen_id, jsonb_build_object('exam_number', st.exam_number));
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. The citizen's own published statements
-- ---------------------------------------------------------------------------

create or replace function public.my_nsc_statements()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(s.published_snapshot order by (s.published_snapshot ->> 'exam_year') desc), '[]'::jsonb)
  from dbe_nsc_statements s
  where s.citizen_id = current_citizen_id()
    and s.citizen_id is not null
    and s.published_snapshot is not null;
$$;

-- Public QR check for a downloaded statement: status only, no marks and no
-- personal details. p_ref is the statement_id (a random UUID).
create or replace function public.verify_nsc_statement_public(p_ref uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'kind', 'nsc_statement',
    'document', 'National Senior Certificate Statement of Results',
    'issuer', 'Department of Basic Education',
    'status', 'published',
    'exam_year', s.exam_year,
    'record_reference', s.record_reference,
    'issued_date', s.published_at::date,
    'expiry_date', null,
    'published_at', s.published_at)
  from dbe_nsc_statements s
  where s.statement_id = p_ref and s.published_snapshot is not null;
$$;

revoke all on function public.nsc_require_dbe_official() from public, anon;
revoke all on function public.sync_nsc_results() from public, anon;
revoke all on function public.publish_nsc_results(uuid[]) from public, anon;
revoke all on function public.confirm_nsc_statement_review(uuid) from public, anon;
revoke all on function public.my_nsc_statements() from public, anon;
revoke all on function public.verify_nsc_statement_public(uuid) from public;
grant execute on function public.nsc_require_dbe_official() to authenticated;
grant execute on function public.sync_nsc_results() to authenticated;
grant execute on function public.publish_nsc_results(uuid[]) to authenticated;
grant execute on function public.confirm_nsc_statement_review(uuid) to authenticated;
grant execute on function public.my_nsc_statements() to authenticated;
grant execute on function public.verify_nsc_statement_public(uuid) to anon, authenticated;
grant execute on function public.nsc_evaluate(int, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Fictional examination results in the source (only when it's empty)
-- ---------------------------------------------------------------------------
-- * One result for each of up to 12 existing certificates, using the same
--   examination number, ID number and year, with marks that lead to the
--   pass type already on the certificate.
-- * New results for learners with no certificate yet (one Bachelor's, one
--   Diploma, one NSC Pass, one NSC Not Achieved).
-- * Three records that must be flagged for review: an unknown identity
--   number, an incomplete record and a discrepancy with the official outcome.

do $$
declare
  p_bachelor jsonb := '[
    {"subject": "English Home Language", "percentage": 72},
    {"subject": "Mathematics", "percentage": 65},
    {"subject": "Life Orientation", "percentage": 81},
    {"subject": "Physical Sciences", "percentage": 68},
    {"subject": "Life Sciences", "percentage": 74},
    {"subject": "Geography", "percentage": 77},
    {"subject": "isiXhosa First Additional Language", "percentage": 70}]';
  p_diploma jsonb := '[
    {"subject": "English Home Language", "percentage": 58},
    {"subject": "isiZulu First Additional Language", "percentage": 55},
    {"subject": "Mathematical Literacy", "percentage": 47},
    {"subject": "Life Orientation", "percentage": 66},
    {"subject": "Business Studies", "percentage": 44},
    {"subject": "Tourism", "percentage": 52},
    {"subject": "History", "percentage": 41}]';
  p_higher jsonb := '[
    {"subject": "Afrikaans Home Language", "percentage": 52},
    {"subject": "English First Additional Language", "percentage": 45},
    {"subject": "Mathematical Literacy", "percentage": 38},
    {"subject": "Life Orientation", "percentage": 60},
    {"subject": "Consumer Studies", "percentage": 35},
    {"subject": "Hospitality Studies", "percentage": 41},
    {"subject": "Geography", "percentage": 33}]';
  p_nsc jsonb := '[
    {"subject": "isiZulu Home Language", "percentage": 61},
    {"subject": "English First Additional Language", "percentage": 26},
    {"subject": "Mathematical Literacy", "percentage": 45},
    {"subject": "Life Orientation", "percentage": 70},
    {"subject": "Tourism", "percentage": 42},
    {"subject": "Consumer Studies", "percentage": 36},
    {"subject": "Hospitality Studies", "percentage": 33}]';
  p_not_achieved jsonb := '[
    {"subject": "English Home Language", "percentage": 38},
    {"subject": "Sesotho First Additional Language", "percentage": 45},
    {"subject": "Mathematics", "percentage": 22},
    {"subject": "Life Orientation", "percentage": 55},
    {"subject": "Life Sciences", "percentage": 31},
    {"subject": "Geography", "percentage": 28},
    {"subject": "History", "percentage": 35}]';
  schools text[] := array['Masakhane Secondary School', 'Thuthuka High School', 'Phakama Academy',
                          'Ubuntu Comprehensive School'];
  r record;
  i int := 0;
  v_year int;
begin
  if exists (select 1 from dbe_exam_results_source) then
    return;
  end if;

  for r in
    select n.matric_exam_number, n.national_id_number, n.year, n.overall_pass_status, c.first_name, c.last_name
    from dbe_nsc_results n
    join citizens c on c.id_number = n.national_id_number
    where n.year >= 2008 and n.overall_pass_status in ('Bachelor Pass', 'Diploma', 'Higher Certificate')
    order by n.year desc, n.matric_exam_number
    limit 12
  loop
    i := i + 1;
    insert into dbe_exam_results_source (exam_number, exam_year, exam_session, national_id_number, first_name,
                                         last_name, school_name, subjects, official_pass_category)
    values (r.matric_exam_number, r.year, 'November ' || r.year, r.national_id_number, r.first_name, r.last_name,
            schools[1 + i % 4],
            case r.overall_pass_status when 'Bachelor Pass' then p_bachelor
                                       when 'Diploma' then p_diploma else p_higher end,
            nsc_normalise_category(r.overall_pass_status));
  end loop;

  i := 0;
  for r in
    select c.id_number, c.first_name, c.last_name, c.date_of_birth
    from citizens c
    where c.id_number is not null
      and not exists (select 1 from dbe_nsc_results n where n.national_id_number = c.id_number)
      and c.date_of_birth between date '1990-01-01' and date '2007-12-31'
    order by c.id_number
    limit 6
  loop
    i := i + 1;
    v_year := extract(year from r.date_of_birth)::int + 18;
    insert into dbe_exam_results_source (exam_number, exam_year, exam_session, national_id_number, first_name,
                                         last_name, school_name, subjects, official_pass_category)
    values ('9' || lpad(i::text, 9, '0'), v_year, 'November ' || v_year, r.id_number, r.first_name, r.last_name,
            schools[1 + i % 4],
            case i
              when 1 then p_bachelor
              when 2 then p_diploma
              when 3 then p_nsc
              when 4 then p_not_achieved
              -- Incomplete: Geography missing.
              when 5 then p_bachelor - 5
              -- Discrepancy: Diploma marks, but the source says Bachelor's.
              else p_diploma
            end,
            case i
              when 1 then 'Bachelor''s Pass'
              when 2 then 'Diploma Pass'
              when 3 then 'NSC Pass'
              when 4 then 'NSC Not Achieved'
              when 5 then 'Bachelor''s Pass'
              else 'Bachelor''s Pass'
            end);
  end loop;

  -- No citizen holds this (fictional) identity number.
  insert into dbe_exam_results_source (exam_number, exam_year, exam_session, national_id_number, first_name,
                                       last_name, school_name, subjects, official_pass_category)
  values ('9000000099', 2024, 'November 2024', '0001010000000', 'Lerato', 'Fictional',
          'Masakhane Secondary School', p_higher, 'Higher Certificate Pass');
end;
$$;
