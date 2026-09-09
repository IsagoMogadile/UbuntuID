-- declare_citizen_deceased
--
-- Backs the "Death" record type on the Home Affairs "Department Records"
-- screen (lib/features/department_official/domain/department_record_config.dart).
-- Previously that flow did a raw client-side INSERT into dha_death_records
-- only. This RPC wraps that same insert together with a `flagged_records`
-- row, so an admin is notified (via the existing Flagged Records queue --
-- see docs/DATA_MODEL.md) to review and deactivate the citizen's account.
-- No RLS policy change needed: SECURITY DEFINER bypasses `flagged_records`
-- RLS (which only grants admins direct read/write today) the same way
-- `admin_create_department_official` etc. already bypass their own tables'
-- RLS -- see docs/KNOWN_LIMITATIONS.md "Security".
--
-- APPLIED live via the Supabase MCP (migration
-- `declare_citizen_deceased_rpc`) once the MCP connection came back in a
-- later session -- kept here as the source-of-truth copy, matching this
-- project's convention of also documenting RPC SQL in-repo (there is no
-- local migrations directory; docs/database/ is it).

create or replace function public.declare_citizen_deceased(
  p_citizen_id uuid,
  p_date_of_death date,
  p_place_of_death text,
  p_cause_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_citizen citizens%rowtype;
  v_flag_id uuid;
begin
  if not (is_official() and current_official_department_code() = 'HOME_AFFAIRS') then
    raise exception 'Only an active Home Affairs official may declare a death.';
  end if;

  select * into v_citizen from citizens where citizen_id = p_citizen_id;
  if not found then
    raise exception 'Citizen not found.';
  end if;

  insert into dha_death_records (national_id_number, date_of_death, place_of_death, cause_code)
  values (v_citizen.id_number, p_date_of_death, p_place_of_death, p_cause_code);

  insert into flagged_records (citizen_id, reason, status)
  values (
    p_citizen_id,
    format(
      'Home Affairs declared %s %s (ID %s) deceased on %s. Recommend deactivating this citizen''s account.',
      coalesce(v_citizen.first_name, ''),
      coalesce(v_citizen.last_name, ''),
      v_citizen.id_number,
      p_date_of_death
    ),
    'open'
  )
  returning flag_id into v_flag_id;

  return jsonb_build_object('flag_id', v_flag_id, 'citizen_id', p_citizen_id);
end;
$$;

grant execute on function public.declare_citizen_deceased(uuid, date, text, text) to authenticated;
