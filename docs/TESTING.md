# UbuntuID — Testing

## Running the checks

```
flutter analyze
flutter test
flutter build web
```

## What's covered

| File | Covers |
|---|---|
| `test/widget_test.dart` | App boots to the splash screen with an injected fake `SupabaseClient` (no real network call) |
| `test/routing/app_routes_test.dart` | Every `UserRole` maps to its own, distinct dashboard route — the mapping the RBAC guard in `app_router.dart` relies on |
| `test/core/formatters_test.dart` | Date/time/currency display formatting |
| `test/features/domain_labels_test.dart` | `UserListItem.roleLabel` covers every enum value |
| `test/features/department_category_test.dart` | `DepartmentCategory.fromName` classifies every department this project seeds, including the Basic/Higher Education name-collision edge case |
| `test/core/sa_id_generator_test.dart` | Luhn checksum + SA ID number generation/validation (date-of-birth encoding, gender digit range, citizenship digit, deprecated digit, round-trip DOB extraction) |

The organisation registration → admin approval → RLS-gating → scoped-
verification flow (`register_organisation`, `admin_review_organisation`,
`current_org_user_organisation_id()`) has no automated Dart test — it was
verified live via direct Supabase Auth REST + PostgREST calls (sign up →
confirm → blocked → register → still blocked while pending → approved →
unblocked → credential-scope filter confirmed), for the same reasons repository
methods aren't mocked below. See `docs/KNOWN_LIMITATIONS.md`.

## What's deliberately not covered, and why

- **Repository methods** (`CitizenRepository`, `AdminRepository`, etc.) are
  not unit-tested against a mocked `SupabaseClient`. Building a mock
  Postgrest response chain deeply enough to exercise these methods would
  test the mock's behaviour, not Supabase's actual RLS-gated behaviour —
  the kind of false confidence this project's own instructions warn
  against ("don't create meaningless tests just to increase test count").
  The real verification for these is exercising each screen against the
  live Supabase project (RLS is already live and enforced — see
  `docs/KNOWN_LIMITATIONS.md`).
- **The role-based route guard's actual redirect behaviour** (a citizen
  hitting `/admin` gets bounced to Unauthorized) is not covered by an
  automated test, because simulating an authenticated session on a fake
  `SupabaseClient` requires either a real Supabase project or reaching into
  GoTrue's private session state — neither is a stable, meaningful test.
  This was instead verified by code review of `app_router.dart`'s
  `redirect` callback and the `_roleAreaPrefixes` map (see
  `docs/SCREEN_DATABASE_MAP.md` and this session's own reasoning in
  `docs/KNOWN_LIMITATIONS.md`). **Manually verify this before a
  demonstration**: sign in as a citizen, edit the URL bar to `/admin`, and
  confirm you land on Unauthorized, not the admin dashboard.
- **RLS itself** cannot be tested from Flutter at all — it's a database-
  level guarantee. The correct place to verify it is the Supabase SQL
  editor (`select * from citizens;` as different roles) or Supabase's own
  policy testing tools, not a Dart test.

## `flutter build web` — what to check manually afterward

Automated tests don't cover visual/responsive behaviour. Before a
demonstration, manually check (`flutter run -d chrome`, then resize the
window):
- Desktop width: side-by-side content, no horizontal scroll.
- Tablet width (~768px): `RoleNavigationShell` remains usable.
- Mobile width (~375px): bottom navigation and forms remain usable, no
  overflow.
- Refresh the page while logged in on a role dashboard — should stay
  signed in (see `SupabaseService.initialize()` in `main.dart`) and land
  back on the same role's dashboard, not the login screen.
- Refresh while on `/citizen` as a citizen, then manually edit the URL to
  `/admin` — should redirect to Unauthorized, not render the admin screen.
