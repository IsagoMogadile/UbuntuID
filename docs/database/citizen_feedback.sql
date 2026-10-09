-- citizen_feedback
--
-- Citizens give feedback from Settings > Feedback: a complaint, compliment
-- or suggestion, either about a specific department or about UbuntuID as a
-- whole (department_id null), with an optional 1-5 rating of the system.
--
-- Only administrators see feedback across the system. An administrator
-- moves it through acknowledged -> under_investigation -> resolved and can
-- type a response; every update notifies the citizen. Department officials
-- and organisations have no access at all. A citizen sees only their own
-- submissions (and the admin's status/response on them).
--
-- Writes go through the two security-definer RPCs below rather than direct
-- INSERT/UPDATE, so a citizen can't forge a status/response and an admin
-- update always produces the matching notification and audit entry.
--
-- NOT YET APPLIED -- written while the Supabase MCP connection was down.
-- Apply in the Supabase SQL editor (or via MCP), then the Flutter feature
-- (lib/features/feedback/) goes live.

create table if not exists public.citizen_feedback (
  feedback_id    uuid primary key default gen_random_uuid(),
  citizen_id     uuid not null references public.citizens (citizen_id) on delete cascade,
  department_id  uuid references public.departments (department_id) on delete set null,
  feedback_type  text not null check (feedback_type in ('complaint', 'compliment', 'suggestion')),
  rating         smallint check (rating between 1 and 5),
  message        text not null check (length(trim(message)) between 5 and 2000),
  status         text not null default 'submitted'
                 check (status in ('submitted', 'acknowledged', 'under_investigation', 'resolved')),
  admin_response text,
  responded_by   uuid references public.ubuntuid_administrators (admin_id) on delete set null,
  responded_at   timestamptz,
  created_at     timestamptz not null default now()
);

create index if not exists citizen_feedback_citizen_idx on public.citizen_feedback (citizen_id, created_at desc);
create index if not exists citizen_feedback_status_idx on public.citizen_feedback (status, created_at desc);

alter table public.citizen_feedback enable row level security;

drop policy if exists citizen_feedback_select_own on public.citizen_feedback;
create policy citizen_feedback_select_own on public.citizen_feedback
  for select to authenticated
  using (citizen_id = current_citizen_id());

drop policy if exists citizen_feedback_select_admin on public.citizen_feedback;
create policy citizen_feedback_select_admin on public.citizen_feedback
  for select to authenticated
  using (is_admin());

-- No INSERT/UPDATE/DELETE policies: all writes go through the RPCs below.

create or replace function public.submit_citizen_feedback(
  p_feedback_type text,
  p_message text,
  p_department_id uuid default null,
  p_rating smallint default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_citizen_id uuid := current_citizen_id();
  v_feedback_id uuid;
begin
  if v_citizen_id is null then
    raise exception 'Only citizens can submit feedback.';
  end if;

  insert into citizen_feedback (citizen_id, department_id, feedback_type, rating, message)
  values (v_citizen_id, p_department_id, p_feedback_type, p_rating, trim(p_message))
  returning feedback_id into v_feedback_id;

  insert into audit_logs (action, actor_id, actor_type, related_id, related_table, target_citizen_id)
  values ('feedback_submitted', v_citizen_id, 'citizen', v_feedback_id, 'citizen_feedback', v_citizen_id);

  return v_feedback_id;
end;
$$;

create or replace function public.admin_update_citizen_feedback(
  p_feedback_id uuid,
  p_status text,
  p_response text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid;
  v_citizen_id uuid;
  v_status_label text;
  v_response text := nullif(trim(coalesce(p_response, '')), '');
begin
  if not is_admin() then
    raise exception 'Only administrators can update feedback.';
  end if;
  if p_status not in ('acknowledged', 'under_investigation', 'resolved') then
    raise exception 'Invalid feedback status: %', p_status;
  end if;

  select admin_id into v_admin_id from ubuntuid_administrators where auth_user_id = auth.uid();

  update citizen_feedback
     set status = p_status,
         admin_response = coalesce(v_response, admin_response),
         responded_by = v_admin_id,
         responded_at = now()
   where feedback_id = p_feedback_id
  returning citizen_id into v_citizen_id;

  if v_citizen_id is null then
    raise exception 'Feedback not found.';
  end if;

  v_status_label := replace(p_status, '_', ' ');

  insert into notifications (citizen_id, message, channel, delivery_status)
  values (
    v_citizen_id,
    'Your feedback is now ' || v_status_label || '.'
      || coalesce(' Response: ' || v_response, ''),
    'in_app',
    'sent'
  );

  insert into audit_logs (action, actor_id, actor_type, related_id, related_table, target_citizen_id, metadata)
  values ('feedback_status_updated', v_admin_id, 'administrator', p_feedback_id, 'citizen_feedback', v_citizen_id,
          jsonb_build_object('status', p_status));
end;
$$;

revoke all on function public.submit_citizen_feedback(text, text, uuid, smallint) from public, anon;
grant execute on function public.submit_citizen_feedback(text, text, uuid, smallint) to authenticated;
revoke all on function public.admin_update_citizen_feedback(uuid, text, text) from public, anon;
grant execute on function public.admin_update_citizen_feedback(uuid, text, text) to authenticated;
