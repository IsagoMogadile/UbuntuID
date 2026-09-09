-- Fix: organisation self-registration's credential-type picker showed an
-- empty list. `OrganisationRegistrationScreen` (step 2 of the wizard) reads
-- `allCredentialTypesProvider` -> `credential_types` joined to
-- `departments(department_name)` -- before the applicant has called
-- `signUp` (a brand-new registrant has no session yet), so `auth.uid()` is
-- null at that point.
--
-- `credential_types_select` required `auth.uid() IS NOT NULL`, and
-- `departments_select` was scoped to the `authenticated` role only (no
-- policy at all for `anon`) -- so an unauthenticated applicant got zero
-- rows back from both, silently (not an error, just an empty checkbox
-- list).
--
-- Fix: both are non-sensitive reference/directory data (type codes, display
-- names, department names -- no citizen or PII exposure), so widen both to
-- allow public (anon + authenticated) read access. Existing authenticated
-- behaviour is unchanged (credential_types_select still returns every row,
-- not just active ones, to a signed-in caller).
--
-- APPLIED live via the Supabase MCP (migration
-- `public_read_credential_types_and_departments_for_org_signup`).

drop policy if exists credential_types_select on public.credential_types;
create policy credential_types_select
  on public.credential_types
  for select
  to public
  using (auth.uid() is not null or active = true);

drop policy if exists departments_select on public.departments;
create policy departments_select
  on public.departments
  for select
  to public
  using (true);
