// Where the signed-in session is kept. On the web it lives in this browser
// tab only (sessionStorage), so a refresh keeps you signed in but a new tab
// or window asks you to sign in again. Elsewhere, null = Supabase's default.
export 'tab_session_store_stub.dart' if (dart.library.js_interop) 'tab_session_store_web.dart';
