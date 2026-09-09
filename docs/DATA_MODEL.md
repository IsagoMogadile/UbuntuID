# UbuntuID — Data model

This describes the relational structure this project relies on, as it
exists live in Supabase today. Where a note calls out something as no
longer part of the model, it means the table was actually dropped — this
document was rewritten after the department-table replacement and
organisation-registration sessions, not patched around the old one.

## Identity & roles

Four independent tables, each with its own primary key and an
`auth_user_id` linking to Supabase Auth's `auth.users`. There is no single
"users" table — `RoleService.detectRole` checks each in turn:

```
auth.users (Supabase Auth, not in `public`)
     │  auth_user_id
     ├── citizens (citizen_id pk, id_number unique)
     ├── department_officials (official_id pk) ──> departments (department_id pk)
     ├── organisation_users (organisation_user_id pk) ──> organisations (organisation_id pk)
     └── ubuntuid_administrators (admin_id pk)
```

All four role tables carry `id_number` (13-digit SA ID, Luhn-validated,
unique per table — see `lib/core/utils/sa_id_generator.dart`), `gender`,
and an auto-generated `email`. `citizens` additionally carries
`citizenship_status` and `is_active`.

Every `department_officials`/`ubuntuid_administrators` row also has a
matching `citizens` row (same `id_number`, a *different* `auth_user_id` —
see `docs/database/officials_and_admins_are_also_citizens.sql`) — a real
person's personal citizen identity, separate from their work login.
`RoleService.detectRole` checking `citizens` first means these can never
share one `auth_user_id` with the work account without breaking role
detection, so they're deliberately two logins for one person, not one.

## Departments (9, each with its own tables)

```
departments (department_id pk, department_code, department_name, category)
```

| Department | Tables |
|---|---|
| Home Affairs | `dha_marital_records`, `dha_death_records`, `dha_passports`, `dha_immigration_records` |
| Transport | `dot_driver_licences`, `dot_vehicles` (a vehicle row *is* the number-plate registration — `registration_number` + `owner_id`, not a separate table) |
| National Treasury (SARS) | `sars_taxpayers`, `sars_tax_returns` |
| Police (SAPS) | `saps_criminal_records`, `saps_clearance_certificates`, `saps_wanted_persons` (department-wide list, not per-citizen) |
| Basic Education (DBE) | `dbe_nsc_results` (the matric certificate) |
| Higher Education (DHET) | `dhet_student_enrollment`, `dhet_nsfas_funding`, `dhet_academic_records`, `dhet_institutions` (reference: 6 universities + 3 TVET colleges) |
| Social Development (SASSA) | `sassa_grants` (flat: grant type/status/payout method) |
| Employment and Labour | `labour_employment_records` (employer, status, UIF) |
| Human Settlements (`DHS`) | `properties`, `housing_beneficiaries`, `title_deeds`, `housing_applications` — **not** `national_id_number`-keyed like the rest of this table; see below |

Human Settlements (`DHS`) is the 9th department, added after the roster was
long documented as "exactly 8" (see docs/KNOWN_LIMITATIONS.md) — its RLS
already existed from an earlier session; only the `departments` row and the
Flutter-side record types/dashboard category were missing.
`properties`/`title_deeds`/`housing_applications` don't have a
`national_id_number` column at all — a citizen reaches a property only
through `housing_beneficiaries.citizen_id`, and a title deed only through
`title_deeds.property_id`, which is why `title_deeds` embeds as a **List**
under `properties` (no unique constraint on `title_deeds.property_id` — see
docs/KNOWN_LIMITATIONS.md's `_latestDeedStatus` fix).

`dha_immigration_records`, `saps_wanted_persons`, `dhet_academic_records`,
`dhet_institutions`, and `labour_employment_records` were added in the
"department services expansion" session — see `docs/database/` for the SQL
and `docs/SCREEN_DATABASE_MAP.md` §3 for the screens. Employment and Labour
previously had **no** dedicated table (a generic `credentials` row against
`LABOUR_STATUS` only) — that placeholder is gone; `labour_employment_records`
is now the authoritative detail table like every other department has.

Every one of these tables has a `national_id_number` column that is a
plain `text` FK to `citizens(id_number)` — **not** `citizens.citizen_id`.
This was a deliberate choice (matching the department-table spec as
given) rather than a rename of the citizen identity column, which stayed
`id_number` everywhere else in the app/RLS.

Employment and Labour now has its own table, `labour_employment_records`
(added in the department-services-expansion session) — it previously had
none, and its one verifiable fact lived only as a generic `credentials` row
(see below).

## Credentials (cross-department verification spine)

```
credential_types (credential_type_id pk, type_code, display_name) ──> departments (issuing_department_id)
     │
     └── credentials (credential_id pk) ──> citizens (citizen_id)
```

8 types exist: `PASSPORT`, `DRIVERS_LICENCE`, `TAX_COMPLIANCE`,
`CRIMINAL_CLEARANCE`, `NSC`, `TERTIARY_QUALIFICATION`, `LABOUR_STATUS`,
`SASSA_STATUS`. A `credentials` row is the generic pointer the
verification workflow (below) reads; the department-specific tables above
hold the authoritative detail. Writing both is an application-level
convention (done in the seed script and would need to be done by any
future "register a passport" official-facing form too) — there is no
database trigger keeping them in sync.

`nqf_level` and the old `qualifications` subtype table **no longer
exist** — DBE/DHET credentials are `dbe_nsc_results`/`dhet_student_enrollment`
now, not a generic qualifications row.

## Organisations & registration

```
organisations (organisation_id pk, registration_status: pending|approved|declined)
     ├── organisation_users (organisation_user_id pk, user_role: manager|administrator|member)
     └── organisation_credential_scopes (organisation_id, credential_type_id)  -- what this org may verify
organisation_verifications (…) ──> organisations, ubuntuid_administrators   -- one row per admin review decision
```

`organisation_credential_scopes` is chosen at registration
(`register_organisation` RPC) and editable only by resubmitting a declined
application (`resubmit_organisation` RPC) — never a direct client write.
`current_org_user_organisation_id()` (used throughout RLS) resolves to
`NULL` unless `registration_status = 'approved'`, which is what actually
blocks a pending/declined organisation's staff from citizen data.

## Verification

```
verification_requests (request_id pk)
     ├──> citizens (citizen_id)
     ├──> organisations (organisation_id)
     ├──> consent_grants (consent_id, NOT NULL)
     └──> job_applications (application_id, optional)

verification_results (result_id pk)
     ├──> verification_requests (request_id)
     ├──> credential_types (credential_type_id)
     └──> department_officials (checked_by_official_id)
```

`overall_status` is `CHECK`-constrained to `pending, processing, completed,
partially_verified, failed, rejected, cancelled`. `match_status` on
results is `exact_match, partial_match, no_match, not_found, expired,
restricted, pending`.

`OrganisationRepository.getCitizenCredentialsForVerification` narrows the
credentials shown to only the organisation's `organisation_credential_scopes`
— an application-layer filter, not an RLS one (see `docs/KNOWN_LIMITATIONS.md`).

## Households (citizen addresses & property)

```
properties (property_id pk)
     └── housing_beneficiaries (citizen_id, property_id, beneficiary_role: owner|co_owner|occupant)
citizen_addresses (citizen_id, matches the household's property address)
housing_applications (citizen_id, programme_id) ──> housing_programmes
title_deeds ──> properties
human_settlements_records (citizen_id, property_id, housing_application_id)
```

Every citizen belongs to exactly one property via `housing_beneficiaries`
(households of 1-5 people); a property's `owner` and `co_owner` (where one
exists) are also recorded as spouses in `dha_marital_records`.
`housing_applications`/`title_deeds`/`human_settlements_records` only
cover a subset of households (the original 152 citizens; the 100+38 added
since have no property at all — see docs/KNOWN_LIMITATIONS.md). The
Human Settlements department (`DHS`) now manages this data as a real
departmental workflow (see above) — `human_settlements_records` itself
remains admin-only oversight (`docs/SCREEN_DATABASE_MAP.md` §9), not read
by the `DHS` official-facing screens, which go through
`properties`/`title_deeds`/`housing_applications` directly.

## SASSA (simulated, view-only for citizens)

```
sassa_grants (grant_id pk) ──> citizens (national_id_number)
```

A single flat table (grant_type, status, payout_method) — the previous
4-table lifecycle model (`sassa_grant_types`/`sassa_grant_applications`/
`sassa_grant_details`/`sassa_grant_payments`) and `dependents` were
dropped and replaced. `SassaScreen` reads this table directly via
`CitizenRepository.getSassaGrants()`.

## `job_applications` / `job_postings` — organisation-side only

Only the employer organisation (Karoo Insurance & Employment Group) has
`job_postings`/`job_posting_requirements` populated; never read or written
by any citizen-facing screen (see `docs/PROJECT_SCOPE.md`).

## Documents, notifications, audit, flagged records

```
documents (document_id pk) ──> citizens (citizen_id)
notifications (notification_id pk) ──> citizens, verification_requests (related_verification_request_id)
audit_logs (log_id pk)               -- write-only via triggers, never client INSERT
flagged_records (flag_id pk) ──> citizens, credentials, verification_results, ubuntuid_administrators (assigned_admin_id)
compliance_audits (audit_id pk)      -- periodic rollup, no screen built against it yet
```

## Tables that exist but are never read or written by the Flutter app

`department_data_records`, `department_data_definitions`, and
`identity_status_records` were dropped (0 rows, never read anywhere).
`appeals`, `organisation_verifications` remain unused. `job_postings`/`job_posting_requirements`/`job_applications`
were dropped this session. `compliance_audits`,
`human_settlements_records`/`human_settlement_data_definitions`, and
`citizen_addresses` are **now used** — see `docs/SCREEN_DATABASE_MAP.md`
§9. See `docs/FUTURE_WORK.md`.
