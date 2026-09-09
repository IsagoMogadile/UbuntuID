# UbuntuID — Future work

Explicitly **not** part of this prototype's current scope
(`docs/PROJECT_SCOPE.md`). Listed here so it reads as a roadmap, not a
hidden gap.

**Rewritten after the department-table replacement + organisation-
registration sessions.** Items from earlier versions of this file that are
now done (Employment & Labour's blank dashboard, the Basic/Higher
Education split, RLS being live) are removed rather than kept as
history — see `docs/KNOWN_LIMITATIONS.md` if you need that trail.

## Out of scope by design (not "missing")

- **Real integration with SASSA, Department of Home Affairs, SARS, SAPS,
  the Department of Transport, or any other government system.** All such
  data is simulated in this project's own Supabase schema. The
  repository-layer architecture (`UI → Provider → Repository → Supabase`)
  would let a future phase swap a repository method's body for a real API
  call without touching the UI, but building that integration is future
  work, not a requirement of this project.
- **A dedicated Human Settlements department/official.** Household and
  property data exists purely to make citizen records realistic
  (`docs/PROJECT_SCOPE.md` §5) — building an actual department around it
  was never in scope.

## Genuinely open next-phase items

- ~~Organisation credential-type scope is enforced at the application
  layer, not RLS.~~ — **done**: `credentials_select_organisation` now folds
  the `organisation_credential_scopes` check directly into the policy
  (`docs/database/tighten_organisation_credential_scope_rls.sql`).
- **`is_org_admin()` / Organisational Head role mismatch.** The RLS helper
  checks `user_role = 'administrator'`, but the Head account created at
  registration is seeded as `'manager'` — so a Head cannot currently
  manage their own organisation's staff under RLS. No staff-management
  screen has been built yet to surface this, but it will need resolving
  before one is.
- **No in-app organisation/department staff self-management screens.**
  Departmental Admins and Organisational Admins have the *intent* of
  managing their own department/organisation's accounts
  (`docs/USE_CASES.md`), but every account today is created by a System
  Administrator via `admin_create_department_official` (departments) or
  by the registrant themself (organisations) — there is no
  "add a colleague" flow for either tier.
- **Employment and Labour has no dedicated record table.** Unlike the
  other 7 departments, it only has a generic `credentials` row
  (`LABOUR_STATUS`) with no underlying detail table — a real
  `labour_employment_records`-style table (employer, start date, UIF
  contribution history) would make this department's data as rich as the
  others.
- **`department_data_records`, `department_data_definitions`,
  `identity_status_records`, `compliance_audits`, `appeals`,
  `housing_programmes`, `human_settlement_data_definitions` are not read
  or written anywhere in the Flutter app.** Kept rather than dropped since
  no explicit decision was made to remove them (see `docs/DATA_MODEL.md`).
- **Document Storage is not wired up.** `storage.buckets` is empty live —
  `DocumentDetailScreen` only ever displays `documents` table metadata
  (file name, type, status), never an actual file.
- ~~Full department/organisation CRUD (create, not just status toggle /
  approve-decline) for administrators~~ — **done for departments**:
  `DepartmentFormScreen` (`AppRoutes.adminDepartmentNew`), via
  `AdminRepository.createDepartment`. Organisation create is still
  self-service registration only (by design — see
  `OrganisationRegistrationScreen`), not an admin-initiated form.
- Two-factor authentication (the settings toggle exists but is disabled).
- ~~A "Compliance Reports" screen reading `compliance_audits`~~ — **done**:
  `ComplianceAuditsListScreen` now has a PDF export button
  (`ReportExport.exportPdf`).
- A citizen-facing "My employment record" view, once Employment and
  Labour has a real detail table to back it.
- Real automated tests against a seeded local Supabase instance (e.g. via
  the Supabase CLI's local dev stack) rather than pure-logic unit tests
  only.

## Already done (moved out of "future work")

Kept here briefly so nobody re-proposes them: all 8 departments have their
own tables and at least one credential type / verification result each ·
every organisation has at least one verification request · every citizen
has at least one notification · the SA ID generator is a reusable,
unit-tested utility · organisation self-registration, admin approval, and
scoped verification are live and verified end-to-end.
