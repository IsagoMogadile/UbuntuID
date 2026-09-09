-- register_marriage
--
-- Backs the "Marriage" record type on the Home Affairs "Department Records"
-- screen (lib/features/department_official/domain/department_record_config.dart).
-- Replaces a raw client-side INSERT into dha_marital_records with a
-- SECURITY DEFINER RPC so the "check they aren't already married" rule is
-- enforced server-side, not just in the Flutter form -- a second official,
-- or a direct PostgREST call, can't bypass it.
--
-- APPLIED live via the Supabase MCP (migration `register_marriage_rpc`).

create or replace function public.register_marriage(
  p_spouse_1_id text,
  p_spouse_2_id text,
  p_marriage_type text,
  p_date_of_marriage date
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_marriage_id uuid;
  v_existing text;
begin
  if not (is_official() and current_official_department_code() = 'HOME_AFFAIRS') then
    raise exception 'Only an active Home Affairs official may register a marriage.';
  end if;

  if p_spouse_1_id = p_spouse_2_id then
    raise exception 'A citizen cannot marry themselves.';
  end if;

  select spouse_1_id into v_existing
  from dha_marital_records
  where spouse_1_id in (p_spouse_1_id, p_spouse_2_id) or spouse_2_id in (p_spouse_1_id, p_spouse_2_id)
  limit 1;

  if v_existing is not null then
    raise exception 'One or both citizens are already recorded as married.';
  end if;

  insert into dha_marital_records (spouse_1_id, spouse_2_id, marriage_type, date_of_marriage)
  values (p_spouse_1_id, p_spouse_2_id, p_marriage_type, p_date_of_marriage)
  returning marriage_id into v_marriage_id;

  return jsonb_build_object('marriage_id', v_marriage_id);
end;
$$;

grant execute on function public.register_marriage(text, text, text, date) to authenticated;
