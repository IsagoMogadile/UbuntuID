-- appeal_lodged_notification
--
-- Any department official can lodge an appeal on a citizen's behalf --
-- against one of their department's records, or a general appeal
-- (related_table = 'citizens', related_id = the citizen) for something
-- that isn't one record, or for a department without record screens.
-- The citizen is now told when that happens; an administrator reviews
-- it as before (admin_decide_appeal).

create or replace function public.lodge_appeal(p_citizen_id uuid, p_related_table text, p_related_id text, p_appeal_reason text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_official_id uuid;
  v_department_id uuid;
  v_department_name text;
  v_appeal_id uuid;
begin
  select official_id, department_id into v_official_id, v_department_id
  from department_officials where auth_user_id = auth.uid() and active;

  if v_official_id is null then
    raise exception 'Only an active department official may lodge an appeal.';
  end if;
  if coalesce(trim(p_appeal_reason), '') = '' then
    raise exception 'An appeal reason is required.';
  end if;
  if not exists (select 1 from citizens where citizen_id = p_citizen_id) then
    raise exception 'Citizen not found.';
  end if;

  insert into appeals (
    citizen_id, related_table, related_id, department_id, appeal_reason,
    status, submitted_at, lodged_by_official_id
  )
  values (
    p_citizen_id, p_related_table, p_related_id, v_department_id, trim(p_appeal_reason),
    'submitted', now(), v_official_id
  )
  returning appeal_id into v_appeal_id;

  select department_name into v_department_name from departments where department_id = v_department_id;
  insert into notifications (citizen_id, channel, message, delivery_status, sent_at)
  values (p_citizen_id, 'in_app',
          coalesce(v_department_name, 'A government department') || ' lodged an appeal on your behalf: '
            || left(trim(p_appeal_reason), 300) || '. A UbuntuID administrator will review it and let you know the outcome.',
          'sent', now());

  return jsonb_build_object('appeal_id', v_appeal_id);
end;
$function$;
