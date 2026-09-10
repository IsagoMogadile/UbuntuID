# Deployment (Vercel)

Vercel has no built-in Flutter support, and this app has no server side of
its own to keep secrets on -- Supabase is called directly from the browser,
secured by RLS (see `PROJECT_SCOPE.md`). Two consequences:

- `vercel.json` sets `"framework": null` and points at
  `scripts/vercel-build.sh`, which installs the Flutter SDK itself (Vercel's
  build image doesn't have one) before running `flutter build web`.
- `SUPABASE_URL`/`SUPABASE_ANON_KEY` are compiled into the JS bundle at
  build time via `--dart-define`, not loaded at runtime from a `.env` file
  (Flutter Web can't read a gitignored file that was never shipped to the
  browser -- see `lib/core/config/env_config.dart`). The anon key is
  designed to be public; RLS is what actually protects the data.

## One-time setup on Vercel

1. Import the GitHub repo into a new Vercel project.
2. Project Settings -> Environment Variables, add for all environments
   (Production/Preview/Development):
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   (same values as your local `dart_defines.json` -- from the Supabase
   project's Settings -> API page.)
3. Leave Framework Preset as "Other" -- `vercel.json` already sets the
   build/output config, nothing to pick in the dashboard.
4. Deploy. First build takes longer than a typical Vercel deploy (~3-5 min)
   since it clones the Flutter SDK from scratch every time; there's no
   Flutter-specific build cache configured.

## Local development

`flutter run`/`flutter build` need the same two values. Copy the example
file and fill in real values (gitignored, same as `.env` was):

```
cp dart_defines.example.json dart_defines.json
flutter run --dart-define-from-file=dart_defines.json
```
