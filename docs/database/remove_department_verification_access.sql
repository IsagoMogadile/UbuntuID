-- remove_department_verification_access
--
-- Correction to this session's own earlier verification-automation work:
-- department officials should have NO involvement in verification at
-- all -- not decide it (already locked down), not even see it day to day.
-- An organisation requests it, an automated check
-- (start_verification/complete_verification) decides it; a department
-- official's role in the whole flow is zero. Their only prior access was
-- read-only (`verification_requests_select_department`, and transitively
-- `verification_results` via `can_view_verification_request`'s
-- `department_official_can_see_request` branch) -- removed here. Every
-- Flutter-side route/nav entry that let a department official reach this
-- was already removed in the same session (see docs/DECISIONS.md); this
-- is the matching database-level change, queued because the Supabase MCP
-- connection was down when it was written.
--
-- Administrators keep full access (`is_admin()` branch, unaffected) --
-- that's the "in case of audits" exception: an admin can still look at
-- any verification's history, a department official cannot.
--
-- APPLIED 2026-09-10 via Supabase MCP.

drop policy if exists verification_requests_select_department on public.verification_requests;

create or replace function public.can_view_verification_request(p_request_id uuid)
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select exists (
    select 1 from verification_requests vr
    where vr.request_id = p_request_id
      and (
        is_admin()
        or vr.organisation_id = current_org_user_organisation_id()
        or vr.citizen_id = current_citizen_id()
      )
  );
$$;
