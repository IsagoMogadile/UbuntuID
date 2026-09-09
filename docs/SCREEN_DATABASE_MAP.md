# UbuntuID — Screen ↔ Supabase Schema Map

Every major screen in the UbuntuID Flutter app mapped to the real,
currently-live Supabase schema. **Rewritten** after the department-table
replacement and organisation-registration sessions — anything the older
version of this document said about a generic `credentials`-only model,
a 4-table SASSA lifecycle, or a 9-department roster is superseded.

Architecture in every case is `UI → Riverpod provider → Repository/Service
→ Supabase`; no widget queries Supabase directly.

---

## 1. Authentication

| Screen | Role | Table(s) | Notes |
|---|---|---|---|
| Splash | Any | `citizens`/`department_officials`/`organisation_users`/`ubuntuid_administrators` | `RoleService.detectRole` tries each in turn by `auth_user_id` |
| Login | Any | *(GoTrue)* | `signInWithPassword`; has a "Register your organisation" link |
| Register | Any | *(GoTrue)* | Citizen/generic self-registration; a new account has no role row until linked |
| **Register Organisation** *(new)* | Prospective org head | `organisations`, `organisation_users`, `organisation_credential_scopes`, `credential_types` | `signUp` (if no session), then `register_organisation` RPC. Requires email confirmation live — if `signUp` returns no session, the same screen becomes reachable from Account Not Configured after confirming |
| Forgot / Reset password | Any | *(GoTrue)* | |
| Account not configured | Any | Same 4 role tables | Now also offers "Finish registering your organisation" |

---

## 2. Citizen

View-only by design — no upload, no apply, no application-submission screen.

| Screen | Table(s) | Notes |
|---|---|---|
| Dashboard | `citizens`, `documents`, `notifications` | |
| Digital Identity | `citizens`, `credentials`, `credential_types` | 8 credential types now (no `qualifications`/`nqf_level` — see `docs/DATA_MODEL.md`) |
| Documents (list/detail) | `documents` | SELECT only |
| SASSA | `sassa_grants` | Flat table (`getSassaGrants()`) — **fixed this session**, was querying the dropped `sassa_grant_applications`/`sassa_grant_payments` tables and would have thrown |
| Human Settlements | `housing_beneficiaries`, `properties`, `title_deeds`, `housing_applications` | Every citizen has a property via household membership; applications only exist for a subset |
| Verification requests (list/detail) | `verification_requests`, `verification_results` | Read-only |
| Notifications (list/detail) | `notifications` | `is_read` + `mark_notification_read` RPC; every citizen has at least one welcome notification |
| Profile / Personal information | `citizens` | |

---

## 3. Department Official

| Screen | Table(s) | Notes |
|---|---|---|
| Dashboard | `departments`, `department_officials`, `verification_requests`/`results`, plus category stats: `citizens` (Home Affairs), `sassa_grants` (SASSA), `credentials` (Basic/Higher Education), `saps_clearance_certificates` (SAPS) | **Fixed this session**: SASSA stats and SAPS clearance count were querying dropped tables |
| Citizen Search (generic) | `citizens` | Available to every official regardless of department |
| Register Citizen (Home Affairs only) | `citizens` | INSERT, gated by `citizens_insert` RLS (`department_code = 'HOME_AFFAIRS'`); now auto-generates the citizen's email server-side if not supplied |
| Clearance Search (SAPS only) | `citizens`, `saps_clearance_certificates` | **Rewritten this session** — no longer joins through `credentials`/`criminal_clearance_records` (dropped); queries `saps_clearance_certificates` directly by `national_id_number` |
| Department services | `credential_types` filtered by `issuing_department_id` | Every department now has ≥1 credential type (Employment & Labour and SASSA were 0 — fixed this session) |
| Verification requests (list/detail) | `verification_requests`, `verification_results`, `credential_types` | Every department now has ≥2 verification results (SAPS was 0 — fixed this session) |
| Colleagues | `department_officials` | Fellow officials in the same department |
| Profile | `department_officials`, `departments` | |
| Edit Citizen (Home Affairs only) | `citizens` | UPDATE, gated by `citizens_update` RLS (same `HOME_AFFAIRS`-or-admin check as `citizens_insert`) — name/DOB/contact/gender/citizenship status |
| Wanted List (SAPS only) | `saps_wanted_persons`, `citizens` | Department-wide list (not per-citizen) — add a citizen to the list, mark Apprehended/Cleared |
| Offenders (SAPS only) | `saps_criminal_records`, `citizens` | Department-wide read view over the existing table — previously only visible per-searched-citizen |

Department-specific record screens (register a marriage/death/passport,
issue a licence, record a tax return, etc.) **are built** — one
config-driven screen, `DepartmentCitizenRecordsScreen`
(`/department-official/citizen-records`), reads
`recordTypesForDepartment(departmentCode)` (`department_record_config.dart`)
to render the right fields per department against the
`dha_*`/`dot_*`/`sars_*`/`saps_*`/`dbe_*`/`dhet_*` tables. (This paragraph
previously said these were seed-script-only; that was stale.) The "Death"
record type is the one exception that doesn't go through a plain
`insertRecord` — see `declareCitizenDeceased` in
`lib/features/department_official/data/department_repository.dart`, which
also raises a `flagged_records` entry notifying an administrator to
deactivate the citizen's account (`docs/database/declare_citizen_deceased.sql`).
Most record types now also support edit (e.g. revoking a passport) and
SASSA additionally supports remove, via `updateRecord`/`deleteRecord` —
see `docs/KNOWN_LIMITATIONS.md` "Department services expansion". The
"Marriage" record type goes through the `register_marriage` RPC, not a
plain insert, so a duplicate marriage is rejected server-side
(`docs/database/register_marriage.sql`).

---

## 4. Organisation User

| Screen | Table(s) | Notes |
|---|---|---|
| Dashboard | `organisations`, `organisation_users`, `verification_requests` | **New this session**: shows a pending/declined banner instead of stats when `registration_status != 'approved'`; declined + head → "Resubmit application" |
| Verify Citizen (search) | `citizens`, `credentials`, `credential_types`, `organisation_credential_scopes`, `verification_requests`, `verification_results` | **Changed this session**: search now requires ID number **and** first name **and** last name (all match, case-insensitive) — was ID-only. Credential list narrowed to the organisation's approved scope |
| Verification requests (list/detail) | `verification_requests`, `verification_results` | Every organisation now has ≥1 request (the NGO partner had 0 — fixed this session) |
| Profile | `organisation_users`, `organisations` | |

---

## 5. Administrator

| Screen | Table(s) | Notes |
|---|---|---|
| Dashboard | `citizens`, `department_officials`, `organisations`, `verification_requests`, `flagged_records`, `audit_logs` | |
| User management (list/detail) | 4 role tables, unioned client-side | |
| Organisation management (list/detail) | `organisations`, `organisation_verifications`, `organisation_credential_scopes` | **New this session**: shows `registration_status` (not just `verified`), and Approve/Decline buttons (`admin_review_organisation` RPC) replace the old toggle-only flow for pending/declined applications |
| Department management (list/detail) | `departments`, `department_officials` | |
| Verification queue | `verification_requests`, `verification_results` | System-wide, unscoped |
| Audit logs (list/detail) | `audit_logs` | Write-only via triggers |
| Flagged records (list/detail) | `flagged_records` | |

---

## 6. Verification (shared module)

One shared repository/widget set across Citizen/Department/Organisation/
Admin. Two tables: `verification_requests` (one row per request) and
`verification_results` (one row per credential type checked within a
request). Approve/reject is offered to department officials/admins only,
while a request is still open. See `docs/DATA_MODEL.md` for the full
column list and status-value constraints.

---

## 7. SASSA — see §2, rewritten to the flat `sassa_grants` model.

## 8. Human Settlements

Citizen side — see §2. Official side (new this session, department code
`DHS`): `DepartmentCitizenRecordsScreen`'s "Property" / "Title Deed" /
"Housing Application" record types, against `properties` (+
`housing_beneficiaries` to link the citizen as owning beneficiary),
`title_deeds`, and `housing_applications` — see
`docs/KNOWN_LIMITATIONS.md` "Human Settlements is now a real department".

## 9. Tables never read by any screen

`department_data_records`, `department_data_definitions`, and
`identity_status_records` were dropped — legacy leftovers, confirmed 0
rows, never read anywhere. `appeals` and `organisation_verifications` (the latter is written by
`admin_review_organisation` but never read back by a screen) remain
unused. `job_postings`/`job_posting_requirements`/`job_applications` were
dropped this session (confirmed not needed).

**Now wired up** (previously listed here as unused): `citizen_addresses`
→ citizen Personal Information screen; `compliance_audits` →
new Admin "Compliance Audits" screen; `human_settlements_records` /
`human_settlement_data_definitions` → new Admin "Household Records"
screen (no department owns this data, so it's admin-only oversight).

## 10. Future work

See `docs/FUTURE_WORK.md` for the current, single source of truth on
what's genuinely still open.
