# UbuntuID — Flutter → Supabase map

Code-first companion to `docs/SCREEN_DATABASE_MAP.md`. Every repository
below lives in `lib/features/*/data/` and follows `UI → Riverpod provider
→ Repository → Supabase`; no widget queries Supabase directly.

## Services

| File | Purpose |
|---|---|
| `lib/services/supabase_service.dart` | `Supabase.initialize()` + the shared `SupabaseClient` getter |
| `lib/services/auth_service.dart` | Thin wrapper over Supabase Auth (sign in/up/out, password reset/update) |
| `lib/services/role_service.dart` | `detectRole()` — checks `citizens`/`department_officials`/`organisation_users`/`ubuntuid_administrators` by `auth_user_id`, in that order |
| `lib/services/service_providers.dart` | Riverpod providers for the above, plus `currentRoleProvider` |
| `lib/core/utils/sa_id_generator.dart` | Luhn checksum + SA ID number generation/validation — reusable, unit-tested (`test/core/sa_id_generator_test.dart`) |
| `lib/core/utils/email_generator.dart` | `firstname.lastname@<domain>` email generation, role-aware (citizen/department/org/admin domains) |

## `CitizenRepository` (`lib/features/citizen/data/citizen_repository.dart`)

View-only by design.

| Method | Tables | Notes |
|---|---|---|
| `getDigitalIdentity` | `citizens` | |
| `getCredentials` | `credentials` → `credential_types` → `departments` | No more `nqf_level`/`qualifications` join |
| `getDocuments` | `documents` | SELECT only |
| `getNotifications` / `markNotificationRead` | `notifications` | |
| `getSassaGrants` | `sassa_grants` | **Renamed this session** from `getSassaApplicationsRaw`/`getSassaPayments`, which queried tables dropped when the SASSA model was flattened |
| `getHousingApplicationsRaw` / `getHousingBeneficiaryProperties` | `housing_applications`, `housing_beneficiaries`, `properties`, `title_deeds` | `title_deeds` embeds as a **List** (no unique constraint on its `property_id`) — see `_latestDeedStatus` in `human_settlements_screen.dart`, docs/KNOWN_LIMITATIONS.md |
| `getServices` | *(static menu, not a query)* | All 5 entries now route somewhere real — previously 3 were marked `available: false` and dead-ended on the generic "coming soon" screen even though the screens they describe already existed |

## `DepartmentRepository`

`department_officials`, `departments`, `credential_types`,
`verification_requests`/`verification_results` for dashboard counts.
`_categoryStats` adds category-specific stats
(`lib/features/department_official/domain/department_category.dart`):
Home Affairs reads `citizens`; SASSA reads `sassa_grants` **(fixed this
session — was `sassa_grant_applications`)**; Basic/Higher Education read
`credentials`; SAPS reads `saps_clearance_certificates` **(fixed this
session — was `criminal_clearance_records`, dropped)**. Employment and
Labour and Transport fall under `DepartmentCategory.other` — base stats
only, no extra cards.

`registerCitizen` (Home Affairs only, INSERT into `citizens`) now
auto-generates the citizen's email via `_generateUniqueCitizenEmail` if
none is supplied, retrying with a numeric suffix on collision.

`searchCitizenForClearance` (SAPS only) queries `saps_clearance_certificates`
directly by `national_id_number` — **rewritten this session**, no longer
joins through `credentials`.

`declareCitizenDeceased` (Home Affairs only, backs the "Death" record type
in `department_record_config.dart`) calls the `declare_citizen_deceased`
RPC — see docs/database/declare_citizen_deceased.sql.

`updateRecord`/`deleteRecord` are generic update/delete-by-primary-key
(mirroring `insertRecord`/`getRecordsByColumn`), used directly by record
types that don't need identifier generation or credential mirroring (SARS
tax returns, SAPS criminal record status, vehicles, immigration records).
`registerMarriage` calls the `register_marriage` RPC (rejects a duplicate
marriage server-side — docs/database/register_marriage.sql).
`updateCitizenDetails`/`getCitizenForEdit` back the Home Affairs "Edit
Citizen" screen. `getWantedPersons`/`addWantedPerson`/`setWantedStatus`/
`getOffenders` back the two SAPS department-wide list screens.

The 8 record types with their own department-assigned identifier and/or a
`credential_types` verification counterpart go through dedicated
issue/update methods instead — `issuePassport`/`updatePassport`,
`issueDriversLicence`/`updateDriversLicence`, `registerVehicle`,
`registerTaxpayer`/`updateTaxpayerCompliance`, `issueClearanceCertificate`,
`issueMatricCertificate`, `enrolStudent`/`updateStudentEnrolment`,
`issueSassaGrant`/`updateSassaGrant`/`removeSassaGrant`,
`recordEmployment`/`updateEmployment`. Each: (1) generates its identifier
server-side via a `next_*`/`generate_*` RPC
(docs/database/auto_generated_official_identifiers.sql) rather than taking
one from the form, and (2) writes/updates the matching `credentials` row
via the private `_issueCredentialMirror`/`_updateCredentialMirror` helpers
— see docs/KNOWN_LIMITATIONS.md "Bugs fixed this session" for why both of
these were missing before.

## `OrganisationRepository`

`organisation_users`, `organisations`, `verification_requests`,
`organisation_credential_scopes`, `credential_types`.

| Method | Notes |
|---|---|
| `searchCitizen(idNumber, firstName, lastName)` | **Replaced this session**'s `searchCitizenByIdNumber` — now requires all three to match (case-insensitive exact) |
| `getCitizenCredentialsForVerification` | **Narrowed this session** to only the organisation's `organisation_credential_scopes` — an application-layer filter, not RLS (see `docs/KNOWN_LIMITATIONS.md`) |
| `requestVerification` | Unchanged: INSERT `consent_grants` then `verification_requests` + `verification_results` |
| `registerOrganisation` | **New this session** — calls the `register_organisation` RPC |
| `resubmitOrganisation` | **New this session** — calls the `resubmit_organisation` RPC, only valid for a declined application's own head user |
| `getApplicationStatus` | **New this session** — drives the dashboard's pending/declined banner |
| `getAllCredentialTypes` / `getOrganisationForResubmit` | **New this session** — back the registration checklist and the resubmit sheet |

## `VerificationRepository` (shared by citizen / department official / organisation / admin)

Unchanged this session: `verification_requests`, `verification_results`,
joined with `citizens` and `organisations`. `getRequests()` scopes itself
by the caller's real role; `decide()` performs the approve/reject UPDATE.

## `AdminRepository`

Unions `citizens`/`department_officials`/`organisation_users`/
`ubuntuid_administrators` for User Management; reads `organisations`,
`departments`, `audit_logs`, `flagged_records` directly.

| Method | Notes |
|---|---|
| `getOrganisations` | **Extended this session** to also select `registration_status`/`decline_reason` |
| `reviewOrganisation` | **New this session** — calls the `admin_review_organisation` RPC (approve or decline, with a note) |
| `setOrganisationVerified`, `setDepartmentActive`, `resolveFlaggedRecord` | Unchanged status-only mutations |
| `createDepartmentOfficial` / `updateDepartmentOfficial` | Unchanged — via `admin_create_department_official` RPC |
| `createDepartment` | **New** — plain client INSERT (`departments_write` RLS already grants `is_admin()` `ALL`, no RPC needed); previously departments were seed data only, no in-app create |
| `streamAuditLogs` | **Changed** — resolves each row's responsible official/administrator/citizen/organisation user by name (`_resolveActorNames`, cached per `actor_type:actor_id`), since `actor_id` is polymorphic and realtime `.stream()` can't embed a join the way a normal PostgREST query could |

## Cross-cutting

- **Auth guard**: `lib/routing/app_router.dart`'s `redirect` blocks unauthenticated access and cross-role navigation; RLS still governs what data those screens can actually read.
- **RLS**: every query above is gated by a live RLS policy. Organisation access additionally depends on `current_org_user_organisation_id()`, which resolves to `NULL` unless `organisations.registration_status = 'approved'` — the single choke point behind every organisation-gated policy.
- **SECURITY DEFINER RPCs**: `_provision_auth_user`, `admin_create_department_official`, `register_organisation`, `resubmit_organisation`, `admin_review_organisation`, `declare_citizen_deceased`, `register_marriage` — every privileged write (creating a login, approving an organisation, raising an admin-facing flag from a department official, enforcing a business rule server-side) goes through one of these rather than a raw client-side INSERT/UPDATE into a privileged table.
