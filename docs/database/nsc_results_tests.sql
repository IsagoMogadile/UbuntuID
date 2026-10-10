-- nsc_results_tests
--
-- Checks the NSC calculation functions from nsc_statement_of_results.sql:
-- achievement levels (including every boundary), each pass category, Life
-- Orientation handling, the language-of-learning rule and the cases that
-- must be flagged for review. Read-only: it only calls pure functions.
--
-- Run in the Supabase SQL editor after the migration. It finishes with
-- "All NSC calculation tests passed." or stops at the first failure.

do $$
begin
  -- Achievement levels, every boundary.
  assert nsc_achievement_level(0) = 1, 'level 0%';
  assert nsc_achievement_level(29) = 1, 'level 29%';
  assert nsc_achievement_level(29.99) = 1, 'level 29.99%';
  assert nsc_achievement_level(30) = 2, 'level 30%';
  assert nsc_achievement_level(39) = 2, 'level 39%';
  assert nsc_achievement_level(40) = 3, 'level 40%';
  assert nsc_achievement_level(49) = 3, 'level 49%';
  assert nsc_achievement_level(50) = 4, 'level 50%';
  assert nsc_achievement_level(59) = 4, 'level 59%';
  assert nsc_achievement_level(60) = 5, 'level 60%';
  assert nsc_achievement_level(69) = 5, 'level 69%';
  assert nsc_achievement_level(70) = 6, 'level 70%';
  assert nsc_achievement_level(79) = 6, 'level 79%';
  assert nsc_achievement_level(80) = 7, 'level 80%';
  assert nsc_achievement_level(100) = 7, 'level 100%';
  assert nsc_achievement_level(101) is null, 'level over 100%';
  assert nsc_achievement_level(-1) is null, 'level negative';
  assert nsc_achievement_level(null) is null, 'level null';

  raise notice 'Achievement levels: ok';
end;
$$;

-- Helper used only by these tests: a seven-subject result. Marks in order:
-- Home Language, First Additional Language, Mathematics, Life Orientation,
-- three electives.
create or replace function pg_temp.nsc_case(
  hl numeric, fal numeric, maths numeric, lo numeric, e1 numeric, e2 numeric, e3 numeric,
  hl_name text default 'English Home Language',
  fal_name text default 'isiZulu First Additional Language',
  maths_name text default 'Mathematics',
  e1_name text default 'Physical Sciences',
  e2_name text default 'Life Sciences',
  e3_name text default 'Geography',
  exam_year int default 2023)
returns jsonb language sql as $$
  select nsc_evaluate(exam_year, jsonb_build_array(
    jsonb_build_object('subject', hl_name, 'percentage', hl),
    jsonb_build_object('subject', fal_name, 'percentage', fal),
    jsonb_build_object('subject', maths_name, 'percentage', maths),
    jsonb_build_object('subject', 'Life Orientation', 'percentage', lo),
    jsonb_build_object('subject', e1_name, 'percentage', e1),
    jsonb_build_object('subject', e2_name, 'percentage', e2),
    jsonb_build_object('subject', e3_name, 'percentage', e3)));
$$;

do $$
declare
  res jsonb;
begin
  -- The example statement: Bachelor's.
  res := pg_temp.nsc_case(72, 70, 65, 81, 68, 74, 77, fal_name => 'isiXhosa First Additional Language');
  assert res ->> 'category' = 'Bachelor''s Pass', 'example statement: ' || res::text;
  assert (res -> 'subjects' -> 0 ->> 'achievement_level')::int = 6, 'example HL level';
  assert (res -> 'subjects' -> 3 ->> 'achievement_level')::int = 7, 'example LO level';

  -- Bachelor's at exactly 50% in four other subjects.
  res := pg_temp.nsc_case(40, 50, 50, 30, 50, 50, 30);
  assert res ->> 'category' = 'Bachelor''s Pass', 'bachelor boundary: ' || res::text;

  -- One of those at 49% -> only three at 50% -> Diploma.
  res := pg_temp.nsc_case(40, 50, 50, 30, 50, 49, 30);
  assert res ->> 'category' = 'Diploma Pass', 'bachelor 49% falls to diploma: ' || res::text;

  -- Life Orientation never counts towards the four Bachelor's subjects.
  res := pg_temp.nsc_case(60, 55, 55, 95, 55, 45, 45);
  assert res ->> 'category' = 'Diploma Pass', 'LO excluded from bachelor count: ' || res::text;

  -- Home Language doesn't count as one of the "other" four.
  res := pg_temp.nsc_case(90, 55, 55, 60, 55, 45, 45);
  assert res ->> 'category' = 'Diploma Pass', 'HL excluded from bachelor count: ' || res::text;

  -- Non-designated subjects don't count for Bachelor's (Tourism).
  res := pg_temp.nsc_case(60, 55, 55, 60, 55, 70, 45, e2_name => 'Tourism');
  assert res ->> 'category' = 'Diploma Pass', 'tourism not designated: ' || res::text;

  -- Diploma at exactly 40% in three other subjects.
  res := pg_temp.nsc_case(40, 40, 40, 30, 40, 30, 30);
  assert res ->> 'category' = 'Diploma Pass', 'diploma boundary: ' || res::text;

  -- Only two other subjects at 40% (LO's 80% doesn't help) -> Higher Certificate.
  res := pg_temp.nsc_case(40, 40, 39, 80, 40, 30, 30);
  assert res ->> 'category' = 'Higher Certificate Pass', 'LO excluded from diploma count: ' || res::text;

  -- Higher Certificate: HL 40, two others 40, three others 30, one fails.
  res := pg_temp.nsc_case(40, 40, 30, 40, 30, 30, 10);
  assert res ->> 'category' = 'Higher Certificate Pass', 'higher certificate, one failed subject: ' || res::text;

  -- Life Orientation does count towards the basic NSC requirements: here
  -- it's one of the two "other subjects at 40%".
  res := pg_temp.nsc_case(45, 40, 30, 41, 30, 30, 20);
  assert res ->> 'category' = 'Higher Certificate Pass', 'LO counts for NSC minimum: ' || res::text;

  -- Home Language at 39% -> not achieved, whatever the rest.
  res := pg_temp.nsc_case(39, 90, 90, 90, 90, 90, 90);
  assert res ->> 'category' = 'NSC Not Achieved', 'HL 39%: ' || res::text;

  -- Two subjects below 30% -> not achieved.
  res := pg_temp.nsc_case(60, 60, 29, 60, 60, 60, 29);
  assert res ->> 'category' = 'NSC Not Achieved', 'two subjects under 30%: ' || res::text;

  -- Only one other subject at 40% -> not achieved.
  res := pg_temp.nsc_case(60, 39, 39, 40, 39, 39, 39);
  assert res ->> 'category' = 'NSC Not Achieved', 'only one other at 40%: ' || res::text;

  -- NSC achieved but English (the only language of learning taken) under 30% -> NSC Pass.
  res := pg_temp.nsc_case(61, 29, 45, 70, 55, 55, 55,
                          hl_name => 'isiZulu Home Language', fal_name => 'English First Additional Language');
  assert res ->> 'category' = 'NSC Pass', 'language of learning under 30%: ' || res::text;

  -- ...and at exactly 30% it's satisfied -> Diploma (FAL 30% doesn't count towards 40% subjects).
  res := pg_temp.nsc_case(61, 30, 45, 70, 55, 55, 55,
                          hl_name => 'isiZulu Home Language', fal_name => 'English First Additional Language');
  assert res ->> 'category' = 'Diploma Pass', 'language of learning at 30%: ' || res::text;

  -- Afrikaans Home Language satisfies the language of learning.
  res := pg_temp.nsc_case(52, 45, 38, 60, 35, 41, 33,
                          hl_name => 'Afrikaans Home Language', fal_name => 'English First Additional Language');
  assert res ->> 'category' = 'Higher Certificate Pass', 'afrikaans HL: ' || res::text;

  -- Review cases: no category is guessed.
  res := nsc_evaluate(2023, (pg_temp.nsc_case(72, 70, 65, 81, 68, 74, 77) -> 'subjects') - 6);
  assert res ->> 'category' is null and jsonb_array_length(res -> 'review_reasons') > 0, 'six subjects';

  res := pg_temp.nsc_case(72, 70, 65, 81, 68, 74, 77, e3_name => 'Underwater Basket Weaving');
  assert res ->> 'category' is null, 'unknown subject';

  res := pg_temp.nsc_case(72, 70, 65, 81, 68, 74, 77, e3_name => 'Physical Sciences');
  assert res ->> 'category' is null, 'duplicate subject';

  res := pg_temp.nsc_case(72, 70, 65, 81, 68, 74, 77, e3_name => 'History', e2_name => 'Mathematical Literacy');
  assert res ->> 'category' is null, 'two mathematics subjects';

  res := pg_temp.nsc_case(72, 70, 65, 81, 68, 74, 77, fal_name => 'English First Additional Language');
  assert res ->> 'category' is null, 'HL and FAL same language';

  res := pg_temp.nsc_case(72, 70, 65, 81, 68, 74, 101);
  assert res ->> 'category' is null, 'mark over 100';

  res := pg_temp.nsc_case(72, 70, null, 81, 68, 74, 77);
  assert res ->> 'category' is null, 'missing mark';

  res := pg_temp.nsc_case(72, 70, 65, 81, 68, 74, 77, exam_year => 2005);
  assert res ->> 'category' is null, 'pre-2008 year';

  res := nsc_evaluate(2023, '[]'::jsonb);
  assert res ->> 'category' is null, 'no subjects';

  -- Category names from other sources.
  assert nsc_normalise_category('Bachelor Pass') = 'Bachelor''s Pass', 'normalise bachelor';
  assert nsc_normalise_category('Diploma') = 'Diploma Pass', 'normalise diploma';
  assert nsc_normalise_category('Higher Certificate') = 'Higher Certificate Pass', 'normalise higher certificate';
  assert nsc_certificate_label('Bachelor''s Pass') = 'Bachelor Pass', 'certificate label';

  raise notice 'All NSC calculation tests passed.';
end;
$$;
