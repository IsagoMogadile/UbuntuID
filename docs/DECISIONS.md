# UbuntuID — Decisions log

A running record of the *why* behind non-obvious choices, kept separate
from `docs/KNOWN_LIMITATIONS.md` (which documents what exists and how it
works) and `docs/PROJECT_SCOPE.md` (what the project is). Newest first.
When a decision is later reversed or superseded, add a new entry rather
than editing the old one — the trail matters.

---

## 2026-09-10 — QA pass found and fixed a real authorization bug

**What happened:** live end-to-end testing (real Auth accounts, real RLS,
not static review) found that `start_verification`/`complete_verification`/
`acknowledge_verification_result` used `if not (is_admin() or v_org_id =
current_org_user_organisation_id())`. For any caller who is *not* an
organisation user at all (a department official, a citizen), that function
returns `NULL`, so `v_org_id = NULL` is SQL `NULL`, `NOT NULL` is `NULL`,
and a `NULL` condition in a PL/pgSQL `IF` is treated as false -- the
exception branch silently never ran. Reproduced live: a test department-
official account successfully called `start_verification` on another
organisation's pending request.

**Fix:** `is_distinct from` instead of `=`, which handles the NULL case
correctly (`NULL IS DISTINCT FROM x` is `TRUE` for any non-null `x`).
Checked every other live function for the same OR-with-nullable-equality
pattern afterward (`grep`-style search over `pg_proc` source) -- nothing
else was affected; every other permission check in this codebase either
does a proper `IS NULL` check on its own variable, or short-circuits
safely through `AND` on an already-boolean left operand.

**Also found in the same pass:** `appeals.related_id` was `uuid`, but 6 of
the 19 department record types this session's "Lodge appeal" feature
targets (passport, driver's licence, vehicle, tax number, criminal record,
matric exam number) have text/varchar primary keys. Widened the column to
`text` (matching `audit_logs.related_id`, which was already `text` for
exactly this "soft reference, not a real FK" reason) rather than
restricting appeals to only the uuid-keyed record types.

**Why this belongs here and not just in a commit message:** both bugs
were introduced by this session's own earlier work and would not have
been caught without actually driving the API as each role, with real
accounts, under real RLS -- static review and `dart analyze` both passed
cleanly the whole time. Recorded so the next session trusts "tests pass"
less and "I drove it as the actual role" more for anything touching
authorization.

---

## 2026-09-10 — Docs cleanup: removed `docs/database/`

**Decision:** deleted every `docs/database/*.sql` file (18 files) once
confirmed applied to the live database. Kept `PROJECT_SCOPE.md`,
`KNOWN_LIMITATIONS.md`, `DATA_MODEL.md`, `SCREEN_DATABASE_MAP.md`,
`FLUTTER_SUPABASE_MAP.md`, `USE_CASES.md`, `TESTING.md`,
`FUTURE_WORK.md`, `STORAGE_POLICY_PROPOSAL.md` (moved up from inside
`docs/database/`, which no longer exists), and added this file.

**Why:** the user found the docs folder cluttered with one-off migration
files that had already served their purpose (every one confirmed applied
live via the Supabase MCP). The narrative of *what* each migration did and
*why* already lives in `KNOWN_LIMITATIONS.md`'s prose — the raw SQL itself
was the only thing tied to those files, and it's recoverable from the live
database schema (`information_schema`, `pg_get_functiondef`) if ever
needed again.

**Trade-off accepted:** existing prose in `KNOWN_LIMITATIONS.md`/
`DATA_MODEL.md` still says "see docs/database/x.sql" in places — those
files no longer exist. Left as historical narrative rather than rewritten,
since the surrounding sentence still explains what happened without the
file. New work should stop pointing at that directory.

---

## 2026-09-10 — Appeals: administrators review, not departments

**Decision:** a department official lodges an appeal (citizen disputes an
existing record, in person); an **administrator** — not another official,
not the same department — reviews and decides it.

**Why:** the user's own words: "official logs a appeal, then someone from
admin will review the appeals (yeah admins review appeals)". This mirrors
the existing `flagged_records` pattern (admin-only oversight) rather than
the department-peer-review model this project doesn't otherwise have
anywhere.

**How applied:** `appeals.reviewed_by_official_id` (an existing, mostly-
empty column pointing at `department_officials`) didn't fit an admin
reviewer, so a new `reviewed_by_admin_id` column was added rather than
repurposing the old one — additive, not a rename, so it can't silently
break anything reading the old column.

---

## 2026-09-10 — Verification claims: reuse `claimed_value`, no new table

**Decision:** when an organisation requests verification, the org worker
types the applicant's claimed details (from the org's own external
application/hiring process) directly into the *existing*
`verification_results.claimed_value` column at request time. No
`job_applications`-style table was added.

**Why:** the user was explicit: "i dont want our db having job stuff...
our system should not be storing organisational job applications stuff."
`claimed_value` already existed, unused, on exactly the right row shape
(one per credential per request) — using it was a fit, not a workaround.

**Alternative considered and rejected:** a single free-text "what does the
applicant claim" box. Rejected in favour of structured per-credential-type
fields (mirroring the real department record's own columns) so the
automated comparison is an honest exact-field match, not fuzzy text
guessing — the user's own choice when asked.

---

## 2026-09-10 — Automated verification wait: ~18s real, not literal 2 minutes

**Decision:** the "automated processing, show progress" step is a real
~18-second client-side countdown, not the literally-requested "maybe 2
minutes."

**Why:** there is no background job scheduler in this stack (confirmed —
no pg_cron, no edge function queue). A true async job would need new
infrastructure this prototype doesn't have. The user chose the shorter
delay explicitly when offered the trade-off (practical to test/demo
repeatedly vs. maximally realistic). The comparison itself is genuinely
automated either way — only the wait duration was shortened.

---

## 2026-09-10 — Verification lock-down is database-level, not UI-only

**Decision:** RLS was tightened so **no one** — organisation, department
official, or administrator — can write `verification_requests.overall_status`
or `verification_results.match_status` directly any more. Only the two new
`SECURITY DEFINER` RPCs (`start_verification`, `complete_verification`)
can.

**Why:** the user's ask was "official admin should not have to confirm
verification" — read as a hard *cannot*, not just a hidden button, and
confirmed explicitly when asked ("Database-level (Recommended)"). Matches
this project's own stated principle (`PROJECT_SCOPE.md` §22/§27):
RLS/the database is the real security boundary, not client-side UI.

---

## 2026-09-10 — Organisation revocation: reversible, reason both ways, no real-time kick

**Decision:** `organisations.registration_status` gained `revoked`
(reversible via a separate `admin_reinstate_organisation` call). Both
revoke and reinstate require a reason. An already-open session for a
revoked organisation is blocked on its *next* navigation/action, not
force-logged-out in real time.

**Why:** all three were explicit user choices. Real-time force-logout
would need a live Realtime subscription — new infrastructure this app
doesn't have — and the existing router guard already re-checks role on
every navigation, so piggybacking on it costs nothing new and matches how
pending/declined organisations already behave.

---

## 2026-09-10 — Universal search stays exact-ID for organisations

**Decision:** department officials and admins got full name/surname/ID
partial search plus "view all" browsing. Organisations kept ID number
mandatory (name matching relaxed from "all three exact" to "at least one,
partial", but no ID-free search and no browse-all).

**Why:** this project's own code comments and `PROJECT_SCOPE.md` §3.3
already treat "no bulk/listing access to citizens for organisations" as a
deliberate boundary ("they dont see everyone") — broadening it to a free
partial-name search would let any approved organisation enumerate the
citizen table by name, which is a real privacy regression a bank or
employer shouldn't get. Flagged to the user rather than silently
implementing it narrower than asked; no objection raised.

---

## 2026-09-10 — Cross-department eligibility rules, and where the floor is

**Decisions:**
- DHET enrolment requires an existing DBE matric record, unless an
  official records an explicit "mature age exemption" with a reason
  (which also raises an admin-reviewable flag).
- NSFAS funding *approval* requires an active ("Enrolled") enrolment and
  no active employment record.
- A new *full-time* employment record is refused while enrolled
  full-time — but not part-time, and not once graduated/dropped.
- The DBE matric age check changed from an implausible 14–25 "plausibility
  window" to a real 17-plus-no-ceiling floor (private/adult-candidate
  route has no upper age limit).

**Why:** all four came directly from the user's own real-world knowledge
of these systems ("i cant be enrolled for university without having a
matric," "i cant be using NSFAS and be employed," "i can get my matric
certificate at any age 17+"), cross-checked against how the schema
actually models each department before writing the rule.

**Known inconsistency left in place:** `fn_enforce_matric_age()` (a
database trigger predating this session) still enforces the *old* 14–25
ceiling at the DB level — only the Flutter-side check and this session's
new seed data were updated to the real 17-plus-no-ceiling rule. The
trigger will reject a matric record for someone over 25 even though the
app itself no longer objects to it. Not fixed here (out of scope for the
task that surfaced it); worth aligning next time this area is touched.

---

## 2026-09-10 — 200 new citizens: youth, randomised, rules-consistent

**Decision:** the new seed data's generation logic itself respects the
same real-world rules the RPCs above enforce (no tertiary record without
matric first; nobody both enrolled full-time and employed), even though
seeding uses raw inserts, not the RPCs. Ages, employment mix,
qualification counts, driver's licence issue dates, and marriage dates
were all constrained to satisfy the live database age-floor triggers
(17 for licences, 18 for tax/marriage, 15 for employment) rather than
being purely random.

**Why:** randomly generated dates that happened to violate a citizen's
real age would have made the *simulated* data internally inconsistent
with the *enforced* rules — a demo where the seed data itself couldn't
have been entered through the real app isn't a good demo. Two migration
attempts failed on exactly these triggers before the fix; documented here
so the next large seed script starts from this list instead of
rediscovering it.

---

## 2026-09-10 — Department Services rebuilt from record types, not credential types

**Decision:** `DepartmentRepository.getServices()` now derives its list
from `recordTypesForDepartment()` (the real per-record-type config) plus
a small per-department "special screens" list (Register a new citizen,
SAPS Wanted List/Offenders/Clearance search), instead of from
`credential_types`.

**Why:** most departments only have one verifiable credential type, so
the old approach showed at most one generic tile no matter how many
record types (Marriage, Death, Passport, Immigration for Home Affairs,
for example) that department actually managed — exactly the "everything
is clustered" complaint. The dashboard's hardcoded per-category tiles
(previously only Home Affairs and SAPS got any) were generalised to the
same data source so all 9 departments get their dedicated screens
surfaced, not just 2.
