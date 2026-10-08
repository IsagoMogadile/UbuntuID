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

  /// Optional. The address QR codes link to, e.g. `https://ubuntuid.vercel.app`
  /// or `http://192.168.1.20:8080` to test scanning with a phone on the same
  /// network. Empty means "wherever the app is currently being served from",
  /// which is right once the app is hosted.
  static const String publicAppUrl = String.fromEnvironment('PUBLIC_APP_URL');
}
