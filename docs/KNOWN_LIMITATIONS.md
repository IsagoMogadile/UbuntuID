# UbuntuID — Known limitations

Honest, current list. This project is a final-year prototype
(`docs/PROJECT_SCOPE.md`) — the limitations below are documented rather
than hidden or silently worked around.

**This file was rewritten after the department-table replacement +
organisation-registration sessions.** Everything below reflects the schema
as it actually is today, verified live via direct Supabase inspection and
real end-to-end API tests (not static review). Anything the previous
version of this file said about a 9-department roster, generic
`licences`/`qualifications`/`tax_records`/`criminal_clearance_records`
subtype tables, or a 4-table SASSA model is **no longer true** — those
tables were dropped and replaced (see `docs/DATA_MODEL.md`).

**`docs/database/` no longer exists.** Every migration file it held was
confirmed applied live and deleted once confirmed (see `docs/DECISIONS.md`'s
"Docs cleanup" entry) — mentions of "see docs/database/x.sql" below are
kept as historical narrative (the surrounding sentence still explains what
happened) rather than rewritten one by one.

## New: live QA pass — 9 department officials, an organisation, a citizen, real RLS

Tested end-to-end via real Supabase Auth accounts + PostgREST calls (same
methodology as the organisation-registration verification in an earlier
session — see `docs/DECISIONS.md`), not static review: one test department
official per department (all 9), an admin, a self-registered organisation,
and a self-activated citizen, all created, exercised, and deleted
afterward. Found and fixed two real bugs this way (both detailed in
`docs/DECISIONS.md`'s "QA pass" entry) — a NULL-comparison authorization
bug in the three new verification RPCs that let *any* authenticated user
start/complete/acknowledge another organisation's verification, and an
`appeals.related_id` type mismatch (`uuid` vs. six record types' text
primary keys) that would have thrown a raw Postgres error from the "Lodge
appeal" button. Confirmed working: RLS blocks a pending/revoked
organisation's data access, `admin_create_department_official`, citizen
registration + department isolation, the full automated verification flow
(matching and mismatched claims), appeals lodge/review/decide, employment
offers, all 9 departments' record creation, several live age-floor
triggers, and citizen self-activation (`claim_citizen_account`).

**New finding, not fixed:** `fn_audit_log`'s `target_citizen_id` resolution
only works for tables with a real `citizen_id` uuid column (`properties`,
`credentials`, `verification_requests`, `appeals`, `flagged_records`,
`organisation_employees`) — it stays `NULL` for the majority of department
detail tables, which key by `national_id_number` (text) instead
(`dha_passports`, `dot_driver_licences`, `dbe_nsc_results`,
`sars_taxpayers`, `sassa_grants`, `labour_employment_records`,
`saps_criminal_records`, the `dhet_*` tables). Confirmed live: an
`insert_dbe_nsc_results` audit row genuinely has no resolvable target
citizen. Pre-existing, not introduced this session — worth fixing next
time audit clarity is touched (`fn_audit_log` would need to also try
resolving `national_id_number` to a `citizen_id` when present).

## New: automated verification, employment offers, organisation revocation, audit clarity

Applied live via the Supabase MCP this session
(`docs/database/automated_verification_and_org_revocation.sql`):

- **Verification is no longer a manual rubber stamp.** Previously a
  department official *or an administrator* could approve/reject any
  verification request with one click -- nothing ever compared anything;
  `claimed_value`/`verified_value` stayed null forever. Now: the
  organisation worker types the applicant's claimed details straight into
  the existing `claimed_value` column at request time (structured fields
  per credential type -- `lib/features/organisation/domain/
  verification_claim_config.dart` -- not a new "job application" table),
  clicks **Start verification**, which flips the request to `processing`;
  a client-side progress countdown (`_processingWait`, 18s -- this project
  has no background job scheduler, see below) then calls
  `complete_verification`, which pulls the real authoritative department
  record for each credential and writes the actual `verified_value`/
  `match_status`, then sets the terminal `overall_status`. Nobody decides
  this by hand any more -- RLS was tightened so the only writers left to
  `verification_requests.overall_status`/`verification_results.match_status`
  are these two `SECURITY DEFINER` RPCs (`verification_requests_update_department`
  and `vres_write`/`vr_write` were dropped entirely).
  - Not a true async job: the "~2 minutes, show progress" ask became a
    real ~18s client-side wait with a countdown UI, not a server-side
    scheduled task -- functionally automated and un-skippable from the UI
    either way, just not literally backgrounded.
  - Once the requesting organisation acknowledges a completed result
    (`acknowledge_verification_result` sets `org_viewed_at`), re-opening
    that request shows only the final status, not the per-credential
    comparison -- a fresh look needs a new request. Department officials,
    administrators and the citizen themselves always see full detail;
    only the requesting organisation's own re-view is restricted.
  - Two new notification points were added (`notify_citizen_on_verification_submitted`,
    and `notify_citizen_on_verification_decision` extended to also fire on
    the `processing` transition) alongside the existing terminal-status
    one -- submitted / being reviewed / done, all three now real.
- **"Offer Employment"** -- a new `organisation_employees` table, the
  organisation's own HR record (job title, salary, start date), entirely
  separate from the government's `labour_employment_records` (still
  LABOUR-official-only). Offered from a completed (fully matched)
  verification result; the citizen sees it via a new "My Employment"
  screen/service tile.
- **Organisation revocation**, reversible. `organisations.registration_status`
  gained a `revoked` value (alongside `pending`/`approved`/`declined`),
  with `revoked_at`/`revoke_reason`/`revoked_by_admin_id` and matching
  `reinstated_*` columns, both requiring a reason
  (`admin_revoke_organisation`/`admin_reinstate_organisation` RPCs).
  Login itself can't be blocked by RLS (Supabase Auth login succeeds
  before any Postgres query runs), so the actual gate is app-side:
  `RoleService.checkAccountActive` is checked right after role resolution
  (`resolveDestinationRoute`, used at splash) and again on every
  navigation within a role area (`app_router.dart`'s
  `_resolveRoleAreaRedirect`, which already re-checked role on every nav
  -- this just piggybacks on it) -- "block on next action", not a
  real-time listener. Extended to `department_officials.active` too,
  which already existed as a column but was never checked anywhere
  either.
- **Audit clarity.** `fn_audit_log`'s actual data capture was already
  broader than expected (34 tables, actor type/id, full row snapshot,
  timestamp) -- the real gap was the admin UI never surfacing
  `target_citizen_id` or `metadata`, and showing the raw
  `update_verification_requests`-style machine action as-is.
  `friendlyAuditAction` (`audit_logs_list_screen.dart`) now turns the
  handful of actions this session added deliberately readable handling
  for into a sentence (organisation approved/declined/revoked/reinstated,
  verification submitted/decided, employment offered); everything else
  still falls back to the raw label rather than fabricating a sentence for
  the other 30-ish tables this wasn't written to understand. The detail
  screen now also shows the resolved target citizen name and the full
  `metadata` payload, both already captured but never displayed.

## New: cross-department eligibility checks + name/ID search

Two real gaps closed this session, both requested directly rather than
found by audit:

- **Search was ID-number-only, exact match, single result, everywhere.**
  `DepartmentRepository`/`AdminRepository` now also have `searchCitizens`
  (any combination of first name, last name, ID number, `ilike` partial on
  the names, returns a list, no filters = "view all" browsing the first 50
  by surname) and `CitizenLookupScreen`/the new `CitizenSearchPanel` render
  that as a selectable result list instead of one inline guess.
  `OrganisationRepository.searchCitizen` (singular, all-three-exact) is now
  `searchCitizens` (plural, list-returning) too, but deliberately keeps ID
  number mandatory and never gets a "view all" — relaxing name matching to
  partial/at-least-one is a UX improvement, dropping the ID requirement
  would reopen the "no bulk/listing access to citizens for organisations"
  boundary this repository's own comments call out (spec: "they dont see
  everyone"). `DepartmentCitizenRecordsScreen`'s own bespoke ID-only search
  box was replaced with the same `CitizenSearchPanel`.
- **Three real-world cross-department rules had zero enforcement**: a
  citizen could be enrolled at university with no matric on file, NSFAS
  funding could be granted to someone with no active enrolment or while
  employed, and a new employment record could be created regardless of
  enrolment status. `docs/database/cross_department_eligibility_checks.sql`
  adds `enrol_student`/`issue_nsfas_funding`/`record_employment` RPCs
  (`SECURITY DEFINER`, same pattern as `register_marriage.sql`) enforcing:
  DHET enrolment requires an existing `dbe_nsc_results` row unless an
  official records an explicit mature-age exemption with a reason (which
  also raises a `flagged_records` entry for admin review); NSFAS *approval*
  requires an "Enrolled" enrolment and no active employment record;
  full-time employment is refused while enrolled full-time (part-time
  enrolment, or no active enrolment, is unaffected). None of these
  auto-flip an existing row in the other department's table — each RPC
  only blocks the *new* conflicting action and explains why; an official
  resolves a real conflict by asking the other department to update their
  own record first (e.g. DHET marks the enrolment Graduated), exactly like
  `register_marriage`'s "already married" check already works. A new
  `study_mode` (Full-time/Part-time) column on `dhet_student_enrollment`
  backs the full-time/part-time distinction. The DBE matric age floor was
  also corrected from an implausible 14-25 "plausibility window" to a real
  17+ with no upper cap (DBE's private/adult-candidate route has no
  ceiling). **Not yet applied to the live database** — the Supabase MCP
  connection was unavailable this session (see below); the Flutter calls
  to `enrol_student`/`issue_nsfas_funding`/`record_employment` will fail
  with "function ... does not exist" until this SQL file's statements are
  run via the Supabase SQL editor or the MCP once reconnected.

## New: dark mode, life timeline, admin analytics, CSV/PDF export

- **Dark mode** was already fully designed (`AppTheme.dark` — same
  green/gold identity, re-balanced for a dark surface) and already active
  by default (`MaterialApp.router` had no `themeMode`, so Flutter fell
  back to `ThemeMode.system`) — it just had no user-facing toggle.
  `ThemeModeController` (`shared_preferences`-backed) + a new Appearance
  settings screen add Light/Dark/System, defaulting to System so nobody's
  first launch changes unasked. Also fixed two widely-shared widgets
  (`DetailRow`, `EmptyState`) that hardcoded a fixed muted-text colour
  instead of the theme's `onSurfaceVariant` token — this was not a full
  app-wide dark-mode contrast audit; some older screens still reference
  fixed `AppColors` constants directly and may read a little flat in dark
  mode.
- **Life-events timeline** (`CitizenTimelineScreen`, a "Timeline" quick
  action on the citizen dashboard) — a chronological feed built from
  `citizens.date_of_birth`/`registered_at`, every `credentials` row
  (already dated), and `dha_marital_records`. Not a new table.
- **Admin analytics** (`AdminAnalyticsScreen`, linked from the dashboard's
  Oversight section) — 4 `fl_chart` charts (registrations/month,
  verification status donut, officials per department, properties per
  province) over `AdminRepository.getAnalytics()`. Chart colours come from
  the active `ColorScheme` (primary/secondary/tertiary/error), not a
  separate palette.
- **CSV/PDF export** (`lib/core/utils/report_export.dart`, `pdf` +
  `printing` + `share_plus`) — CSV on Users and Audit Logs, a PDF
  compliance report on Compliance Audits. Shares an in-memory file via the
  platform share sheet (download on web, save dialog on desktop, share
  sheet on mobile) rather than writing to app-local storage.

## Fixed: organisation credential-scope was app-layer only

Previously `credentials_select_organisation` granted any approved
organisation user row-level SELECT across *all* credential types — the
Flutter app only ever *asked for* the organisation's approved scope
(`organisation_credential_scopes`), so a direct PostgREST call bypassing
the app could have read outside it. Folded the scope check into the RLS
policy itself (`docs/database/tighten_organisation_credential_scope_rls.sql`)
— verified this is the only place the app reads `credentials` as an
organisation user, and it already sent exactly this filter, so no
legitimate query is affected.

## Fixed: the 100+38 citizens added this session had no household

Previously noted here as a real gap. All 292 citizens now have exactly one
property via `housing_beneficiaries` again (118 properties total, up from
51) — married couples share a property as owner/co_owner (matching
existing `dha_marital_records`), everyone else groups into households of
1-3. Title deeds (24) and housing applications (54) cover a similar
partial proportion of the new households as the original ones did, not
every household — intentional partial coverage, same as before. See
`docs/database/household_data_for_new_citizens.sql`.

## Human Settlements is now a real department

Previously "no Human Settlements department or official — housing/property
data exists purely to model realistic citizen households... not as a
departmental workflow" (this file's own prior wording). That's no longer
true: `departments` now has a `DHS` row (Department of Human Settlements),
`DepartmentCategory.humanSettlements` classifies it, and
`department_record_config.dart`'s `'DHS'` case gives Human Settlements
officials Property / Title Deed / Housing Application record types against
the same `properties`/`title_deeds`/`housing_applications`/
`housing_beneficiaries` tables the citizen-side Human Settlements screen
already read. This was mostly *un*-hiding existing infrastructure, not
building new: RLS on all 5 tables already gated writes on
`current_official_department_code() = 'DHS'` from an earlier session, and
`department_category.dart`'s own doc comment already listed `'housing'`
among confirmed live `departments.category` values — the `departments` row
with that code had simply never been created. See
`docs/database/add_human_settlements_department.sql` and
`docs/database/human_settlements_identifier_generators.sql`.

At the time this department was added, it managed only the original 51
properties / 15 housing applications / 9 title deeds — household coverage
for the 100+38 citizens added this session was extended separately
afterwards (see "the 100+38 citizens added this session had no household"
above); it now manages all 118 properties / 54 applications / 24 deeds.

## Officials and administrators are also citizens

Every `department_officials` and `ubuntuid_administrators` row (38 total)
now has a matching `citizens` row too — same `id_number` (one real person,
one SA ID number, regardless of which role table it's read from) and a
derived `date_of_birth` (same YY/MM/DD-from-ID-number logic as
`saIdDateOfBirth`), but a **separate** auth account (own generated email,
`auth_user_id` left `NULL` until self-activated) — not the same login as
their work account. This is intentional, not an oversight:
`RoleService.detectRole` resolves one `auth_user_id` to exactly one role,
checking `citizens` first, so an official/admin whose work login also had a
`citizens` row would get misdetected as a citizen and lose access to their
actual role. A real person having a separate personal citizen identity and
a separate work login is also just how it works in reality.

Each of the 38 was additionally given a full "overly qualified
professional" record set — a matric result, a real tertiary qualification
(`dhet_academic_records` + a matching `dhet_student_enrollment` row,
`completion_status = 'Graduated'`), a driver's licence, a compliant SARS
taxpayer record, and a `labour_employment_records` row showing them
employed at their own department — plus a passport for about half, all
with matching `credentials` rows. See
`docs/database/officials_and_admins_are_also_citizens.sql`.

## ACTION REQUIRED: turn off "Confirm email" in the Supabase dashboard

Self-activation (a citizen registering with the email Home Affairs already
recorded for them, or an organisation registering) is blocked end-to-end
right now -- not by a code bug, by a Supabase Auth **project setting**. This
project's test data uses fake email addresses (`webmail.co.za`, made-up
`.gov.za`/`.invalid` domains, etc.) that can never receive a real message.
With "Confirm email" on, every `signUp` call tries to send a confirmation
email before it will return a session -- and Supabase's built-in email
sender is rate-limited to only a handful of sends per hour (it exists for
occasional manual testing, not a seeded prototype), so real signups start
failing with `429: email rate limit exceeded` almost immediately. Verified
live via `auth_logs`: repeated `over_email_send_rate_limit` errors on
`/signup`, plus at least one `email_address_invalid` rejection on an
otherwise normal-looking address.

**Fix (cannot be done via SQL/MCP -- this setting lives outside the
Postgres database, in Supabase's own Auth service config):** in the
Supabase dashboard, go to **Authentication → Sign In / Providers → Email**
and turn **off** "Confirm email". Once off, `signUp` returns a session
immediately, no email is sent at all, and both flows work instantly:

- `RegisterScreen` (`AppRoutes.register`) → `signUp` → `claim_citizen_account`
  RPC auto-links the new auth account to any `citizens` row whose email
  matches (case-insensitive), already fully implemented and unblocked by
  this one setting alone.
- `OrganisationRegistrationScreen` → `signUp` → `register_organisation` RPC,
  same story -- and there's no server-side email-format strictness in that
  RPC to loosen (checked `register_organisation`'s source directly); the
  only friction was ever the confirmation-send step.

Until that toggle is off, both screens now show a clearer in-app message
for this specific failure (`friendlyAuthError` in
`lib/core/utils/auth_error_messages.dart`) instead of the raw GoTrue error
text.

## Current department roster (live, verified)

9: Home Affairs (`HOME_AFFAIRS`), Transport, National Treasury (SARS),
Police (SAPS), Basic Education (DBE), Higher Education and Training
(DHET), Social Development (SASSA), Employment and Labour, and Human
Settlements (`DHS`, added this session — see "Human Settlements is now a
real department" above). `docs/PROJECT_SCOPE.md` §5 still describes
housing/property data as existing "purely for realism" — that's now
superseded by the `DHS` department itself managing it, though the
underlying data still only covers a subset of citizens (see above).

## Bugs fixed this session

- **Citizen Human Settlements screen crashed** (`type 'String' is not a
  subtype of type 'int'`) whenever a property actually had a title deed.
  `properties(*, title_deeds(*))` embeds `title_deeds` as a **List**
  (`title_deeds.property_id` has no unique constraint, so PostgREST treats
  it as one-to-many), but `human_settlements_screen.dart` did
  `['deed_status']` straight on it -- valid Dart for a `Map`, but a `List`'s
  `[]` operator requires an `int` index, not a `String` key, which is
  exactly that error. Fixed with a `_latestDeedStatus` helper that reads
  the first (most recent) deed from the list, or shows "Not yet
  registered" if the list is empty -- a citizen with no property/deed yet
  is a valid state, not an error.
- **Adding/updating a department record never touched `credentials`.**
  `credentials` is the table the citizen's own Digital Identity screen (and
  the organisation verification flow, and admin oversight) actually reads
  -- but `insertRecord`/`updateRecord` only ever wrote to the
  department-specific detail table (`dha_passports`, `dot_driver_licences`,
  etc.). Writing both was previously only done in the seed script (see
  docs/DATA_MODEL.md's "Credentials" section, which already called this out
  as a known gap for "any future 'register a passport' official-facing
  form"). Fixed: `DepartmentRepository` now has dedicated
  `issuePassport`/`updatePassport`, `issueDriversLicence`/
  `updateDriversLicence`, `registerTaxpayer`/`updateTaxpayerCompliance`,
  `issueClearanceCertificate`, `issueMatricCertificate`, `enrolStudent`/
  `updateStudentEnrolment`, `issueSassaGrant`/`updateSassaGrant`/
  `removeSassaGrant`, and `recordEmployment`/`updateEmployment` methods
  that write the department table **and** mirror/update the matching
  `credentials` row in the same call, via `_issueCredentialMirror`/
  `_updateCredentialMirror`. This is very likely what "I just added a
  licence and it didn't update" was actually seeing -- the licence *was*
  added, but nothing reading `credentials` (Digital Identity, dashboards)
  would ever have shown it.
- **Officials could type a passport/licence/VIN/tax/case/matric identifier
  number by hand.** These are department-assigned, not applicant-chosen.
  Fixed with real Postgres sequences + RPCs
  (`docs/database/auto_generated_official_identifiers.sql|
  next_passport_number`, `next_licence_number`, `next_tax_number`,
  `next_case_number`, `next_matric_exam_number`, `generate_vin_number`,
  `generate_registration_number`) -- the corresponding `RecordField` was
  removed from every affected form in `department_record_config.dart`.
- **Two citizen-profile links dead-ended on the generic "coming soon"
  screen** even though the real, live-data screens they describe already
  existed: Privacy Settings' "Consent management" now opens
  `ConsentManagementScreen` (was already fully built, just never linked);
  the Services grid's "Identity Verification" now opens
  `CitizenVerificationListScreen`, and "Tax & SARS"/"Licences &
  Qualifications" now open `DigitalIdentityScreen` (its credential list
  already includes every credential type, so there was no missing screen,
  only a missing route).
- **Documents weren't seeded for the department-services-expansion
  session's 100 new citizens** (or for a handful of the original 152).
  Backfilled one `documents` row per `dha_passports`/`dbe_nsc_results` row
  that didn't already have a matching one, in the existing seed's own
  convention (`document_type`/`related_table`/`storage_path` shape) --
  `documents` now has exactly one "Passport Copy" per passport (114) and
  one "National Senior Certificate" per NSC result (164).

## Bug fixed: organisation registration's credential-type list was empty

`credential_types_select` required `auth.uid() IS NOT NULL`, and
`departments_select` had no policy for the `anon` role at all — but
`OrganisationRegistrationScreen`'s credential-type picker (step 2 of the
signup wizard) reads both **before** the applicant has called `signUp`.
Fixed by widening both to allow public (anon + authenticated) read access
— both are non-sensitive reference/directory data. See
`docs/database/public_read_credential_types_and_departments.sql`.

## Department services expansion (this session)

Per-department CRUD was extended well beyond create-only for a handful of
department official use cases (`docs/USE_CASES.md`'s spec), and 100 new
citizens were seeded (`citizens` went from 152 to 252) with realistic,
varied department records across all 8 departments — see the individual
`docs/database/*.sql` files for what each migration did. Highlights:

- **5 new tables**: `dha_immigration_records`, `saps_wanted_persons`,
  `dhet_institutions` + `dhet_academic_records`, `labour_employment_records`
  (replacing Employment & Labour's old generic-`credentials`-only
  placeholder).
- **Edit/revoke/remove**, not just create, on passports, driver's licences,
  vehicles, SARS taxpayer/tax-return records, SAPS criminal records, DHET
  enrolment, and SASSA grants (SASSA additionally gets delete — "manage
  update remove") — via `DepartmentRepository.updateRecord`/`deleteRecord`,
  generic by table + primary-key column, no new RLS needed (every
  department table already had an `ALL`-command write policy for its
  owning department, confirmed live — edit/delete were previously just
  never exposed in the UI).
- **`register_marriage`** RPC enforces "reject if either citizen is already
  married" server-side (previously a raw insert with no check at all).
- **SAPS Wanted Persons and Offenders** are department-wide list screens
  (not per-citizen, so they don't fit the existing `RecordTypeConfig`
  pattern) — `SapsWantedPersonsScreen`/`SapsOffendersScreen`, routed from
  the department dashboard for SAPS officials only.
- **Home Affairs "Edit Citizen"** — a citizen's own identity record
  (name/DOB/contact/gender/citizenship status) can now be edited, not just
  created at registration — `EditCitizenScreen`, gated by the same
  `citizens_update` RLS policy `citizens_insert` already used.

### Household coverage

**Fixed** (see "the 100+38 citizens added this session had no household"
above) — every citizen now has exactly one property via
`housing_beneficiaries`, restoring the invariant across the full
`citizens` table, not just the original 152.

## Schema reality

- Seven of the eight departments have their own dedicated tables:
  `dha_marital_records`/`dha_death_records`/`dha_passports`,
  `dot_driver_licences`/`dot_vehicles`, `sars_taxpayers`/`sars_tax_returns`,
  `saps_criminal_records`/`saps_clearance_certificates`,
  `dbe_nsc_results`, `dhet_student_enrollment`/`dhet_nsfas_funding`,
  `sassa_grants` (a single flat table — grant type, status, payout
  method — not the old 4-table lifecycle model).
- **Employment and Labour has no dedicated table.** Its one verifiable
  fact (UIF/employment status) is a generic `credentials` row against the
  `LABOUR_STATUS` credential type, same as `SASSA_STATUS` — both were
  added specifically so the department's Services and Verification-queue
  screens aren't empty, not because a detailed employment-record model was
  built.
- `credentials` / `credential_types` remain the cross-department
  verification spine (8 types total). Each department-specific table above
  is the authoritative detail; a `credentials` row is written alongside it
  only for the 6 types organisations can actually request verification
  against (Passport, Driver's Licence, Tax Compliance, Criminal Clearance,
  NSC, Tertiary Qualification, plus the two Employment/SASSA types) — this
  is an application-level convention (`_provision`-style inserts in the
  seed script), not a database trigger, so a future direct-INSERT into
  e.g. `dha_passports` would **not** automatically create a matching
  `credentials` row.
- `properties` / `housing_beneficiaries` / `citizen_addresses` model
  households: every citizen belongs to exactly one property via
  `housing_beneficiaries`, with matching address rows. `housing_applications`
  / `title_deeds` / `human_settlements_records` only cover a subset of
  households (15 of 51) — intentional partial coverage, not a bug.
- `department_data_records` / `department_data_definitions` /
  `identity_status_records` still exist in the schema (unharmed by the
  table replacement) but are **not read or written anywhere in the Flutter
  app** — dead tables, kept rather than dropped since no explicit decision
  was made to remove them. See `docs/FUTURE_WORK.md`.

## Organisation registration & approval

- `organisations.registration_status` (`pending` / `approved` / `declined`)
  gates access at a single choke point: `current_org_user_organisation_id()`
  returns `NULL` for any organisation not `approved`, and every
  citizen/credential RLS policy that grants organisation access depends on
  that function. A pending or declined organisation's staff can log in
  (their auth account exists immediately, per design) but see nothing.
- Registration, resubmission, and admin approval/decline all go through
  `SECURITY DEFINER` RPCs (`register_organisation`, `resubmit_organisation`,
  `admin_review_organisation`) — verified live end-to-end via the Supabase
  Auth REST API + PostgREST: signed up → blocked from citizen data → applied
  → still blocked while pending → approved by an admin → access opened up →
  confirmed the credential-scope filter returns only the selected types.
- **Credential-type scope filtering is enforced at the application layer,
  not RLS.** `OrganisationRepository.getCitizenCredentialsForVerification`
  filters by `organisation_credential_scopes` in the query, but the
  underlying `credentials_select_organisation` RLS policy still grants any
  approved organisation user row-level SELECT across *all* credential
  types — the client just never asks for the rest. A direct PostgREST call
  bypassing the Flutter app could read outside the declared scope. Tightening
  this into the RLS policy itself (a join against
  `organisation_credential_scopes`) is the correct fix, not done here.
- **`is_org_admin()` checks `user_role = 'administrator'`, but the
  "Organisational Head" role created at registration is `'manager'`.** This
  is a pre-existing mismatch (from the account-seeding session, not the
  registration-workflow session) — the Head currently does **not** satisfy
  `is_org_admin()`, so the `organisation_users` write policy
  (`organisation_id = current_org_id() AND is_org_admin()`) would reject a
  Head trying to manage their own organisation's staff under RLS. Not
  fixed here since no staff-management UI was built to exercise it yet.

## RLS

RLS is enabled and enforced on every table in `public`, including all 14
tables added this session (13 department tables +
`organisation_credential_scopes`), each with department-scoped or
organisation-scoped SELECT/write policies mirroring the pattern already
used by `credentials`.

## Security

- `public._provision_auth_user(email, password, full_name)` and the
  registration/review RPCs above are `SECURITY DEFINER` — they run with
  elevated privilege regardless of the caller's own RLS grants, by design
  (this is how a client with only the anon key can still create an auth
  account or have an admin approve an organisation). Each RPC re-derives
  the caller's identity from `auth.uid()` and re-checks authorisation
  itself (`is_admin()`, ownership of the organisation, etc.) rather than
  trusting any client-supplied ID.
- No service-role key is or should be embedded in the Flutter application.

## Feature-level limitations

- **No document review by officials, and none is planned** — `documents`
  is view-only for citizens by design.
- **Document Storage is not wired up.** `DocumentDetailScreen` only ever
  displays `documents` table metadata, never an actual file.
- **Two-factor authentication** is a visible but disabled toggle
  (`SecuritySettingsScreen`) — genuinely not implemented.
- **Department/organisation CRUD beyond registration/approval** is limited
  to status toggles — no in-app "create a department" flow (departments
  are seed data); organisation creation is the self-service registration
  flow described above, not an admin-initiated create form.

## Bugs found and fixed this session

- **Two live regressions from the department-table replacement**:
  `CitizenRepository` (`getSassaApplicationsRaw`/`getSassaPayments`) and
  `DepartmentRepository` (SASSA category stats, SAPS clearance search)
  still queried `sassa_grant_applications`, `sassa_grant_payments`, and
  `criminal_clearance_records` — all three dropped when those tables were
  replaced. The SASSA citizen screen would have thrown outright; the SAPS
  path was defensively wrapped and would have silently shown 0. Fixed:
  `CitizenRepository.getSassaGrants()` and `SassaScreen` now read the flat
  `sassa_grants` table; `DepartmentRepository` reads `sassa_grants` and
  `saps_clearance_certificates` directly.
- **Structural blank-screen gaps**, found by auditing per-department and
  per-organisation data coverage rather than assuming the reseed was
  complete: Employment & Labour and SASSA had **zero** `credential_types`
  (their Department Services and Verification-queue screens were
  genuinely empty for every official, not just unlucky demo picks); SAPS
  had a credential type but zero `verification_results` ever recorded
  against it; the NGO partner (Thuso) had zero `verification_requests` at
  all, making its dashboard and verification list empty for every login.
  Fixed by adding the two missing credential types and seeding a small
  number of realistic verification requests/results against each gap. 93
  of 147 citizens also had zero notifications (a blank Notifications
  screen); every citizen now has at least a welcome notification.
  Citizen-level variance in documents/credentials (some citizens
  genuinely have none) was left as-is — that's intentional per the
  earlier "some users have credentials, others don't" requirement, not a
  bug, and every affected screen already renders a proper empty state
  rather than an error.

## Testing

See `docs/TESTING.md`. `test/core/sa_id_generator_test.dart` (17 tests)
covers the Luhn checksum and SA ID generation/validation logic added this
session. The organisation registration/approval/RLS-gating flow was
verified live via direct Supabase Auth REST + PostgREST calls (sign up →
confirm → register → blocked → approve → unblocked → scope-filtered), not
by an automated Dart test — there is no mocked-`SupabaseClient` coverage
for any repository method, for the same reasons given in `docs/TESTING.md`.
