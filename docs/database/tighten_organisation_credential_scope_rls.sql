-- Previously documented as a known gap (docs/KNOWN_LIMITATIONS.md,
-- docs/FUTURE_WORK.md): `credentials_select_organisation` granted any
-- approved organisation user row-level SELECT across *all* credential
-- types -- OrganisationRepository.getCitizenCredentialsForVerification
-- narrowed what it *asked for* via organisation_credential_scopes, but a
-- direct PostgREST call bypassing the Flutter app could read outside an
-- organisation's declared scope. Folding the scope check into the policy
-- itself closes that -- verified this is the only place the app reads
-- `credentials` as an organisation user, and it already sends exactly this
-- filter, so no legitimate query is affected.
--
-- APPLIED live via the Supabase MCP (migration
-- `tighten_organisation_credential_scope_rls`).

drop policy if exists credentials_select_organisation on public.credentials;

create policy credentials_select_organisation
  on public.credentials
  for select
  to authenticated
  using (
    current_org_user_organisation_id() is not null
    and credential_type_id in (
      select credential_type_id from organisation_credential_scopes
      where organisation_id = current_org_user_organisation_id()
    )
  );
