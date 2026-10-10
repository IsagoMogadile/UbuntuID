-- marriage_spouse_names
--
-- A citizen's own marriages with their spouse's *name*, for Digital
-- Identity, Personal Information, Home Affairs records and the timeline
-- ("Married to Thandi Mokoena" rather than an ID number).
--
-- Citizens can already read their own dha_marital_records rows, but RLS
-- (rightly) doesn't let them read another citizen's row in `citizens`, so
-- the spouse's name is looked up here in a security-definer function that
-- only ever returns marriages the caller is part of, and only the spouse's
-- name -- nothing else from the spouse's record.
--
-- Safe to re-run. NOT YET APPLIED -- run in the Supabase SQL editor. Until
-- it is, the app falls back to the marriage record without the name.

create or replace function public.my_marriages()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(
           (to_jsonb(m) - 'spouse_1_id' - 'spouse_2_id')
             || jsonb_build_object(
                  'spouse_id_number', case when m.spouse_1_id = me.id_number then m.spouse_2_id else m.spouse_1_id end,
                  'spouse_name', nullif(trim(concat_ws(' ', sp.first_name, sp.last_name)), ''))
           order by m.date_of_marriage desc),
         '[]'::jsonb)
  from citizens me
  join dha_marital_records m on me.id_number in (m.spouse_1_id, m.spouse_2_id)
  left join citizens sp
    on sp.id_number = case when m.spouse_1_id = me.id_number then m.spouse_2_id else m.spouse_1_id end
  where me.citizen_id = current_citizen_id();
$$;

revoke all on function public.my_marriages() from public, anon;
grant execute on function public.my_marriages() to authenticated;
