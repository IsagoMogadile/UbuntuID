/// Read at compile time via `--dart-define`/`--dart-define-from-file`
/// (see README/docs/DEPLOYMENT.md) rather than a bundled `.env` asset --
/// Flutter Web has no server-side process to hold a runtime-loaded
/// secrets file, and a `.env` shipped as a static asset is just a
/// plaintext file fetchable at a public URL. Compiling the values in
/// keeps local dev and CI/Vercel on the same mechanism.
class EnvConfig {
  EnvConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
