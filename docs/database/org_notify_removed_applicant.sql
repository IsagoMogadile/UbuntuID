-- org_notify_removed_applicant
--
-- Bulk upload: when an organisation removes an applicant from an uploaded
-- list it must give a reason, and the citizen is told that something is
-- wrong with their application (and why), so they can fix it and apply
-- again. Recorded in the audit log like other organisation decisions.

create or replace function public.org_notify_removed_applicant(p_citizen_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid := current_org_user_organisation_id();
  v_org_name text;
  v_user_id uuid;
begin
  if v_org_id is null then
    raise exception 'Only an approved organisation user may send application feedback.';
  end if;
  if p_reason is null or trim(p_reason) = '' then
    raise exception 'Give a reason for removing this applicant.';
  end if;
  if not exists (select 1 from citizens where citizen_id = p_citizen_id) then
    raise exception 'Citizen not found.';
  end if;

  select legal_name into v_org_name from organisations where organisation_id = v_org_id;
  select organisation_user_id into v_user_id from organisation_users where auth_user_id = auth.uid();

  insert into notifications (citizen_id, channel, message, delivery_status, sent_at)
  values (p_citizen_id, 'in_app',
          'There is a problem with your application to ' || coalesce(v_org_name, 'an organisation')
            || ', so it was not considered: ' || left(trim(p_reason), 400)
            || '. Please correct this and apply again.',
          'sent', now());

  insert into audit_logs (action, actor_id, actor_type, related_table, target_citizen_id, metadata)
  values ('bulk_applicant_removed', v_user_id, 'organisation_user', 'organisations',
          p_citizen_id, jsonb_build_object('reason', trim(p_reason), 'organisation_id', v_org_id));
end;
$$;

revoke all on function public.org_notify_removed_applicant(uuid, text) from public, anon;
grant execute on function public.org_notify_removed_applicant(uuid, text) to authenticated;
