import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env_config.dart';
import 'tab_session_store.dart';

class SupabaseService {
  SupabaseService._();

  /// Must be called once, before [client] is first used (see `main.dart`).
  /// Using `Supabase.initialize` rather than constructing a bare
  /// [SupabaseClient] is what gives the app session persistence across page
  /// refreshes on Flutter Web, and automatic exchange of the password-reset
  /// email link into a recovery session before `ResetPasswordScreen` runs.
  static Future<void> initialize() {
    final projectRef = Uri.parse(EnvConfig.supabaseUrl).host.split('.').first;
    return Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseAnonKey,
      // Web: the session belongs to this tab only (see tab_session_store.dart).
      authOptions: FlutterAuthClientOptions(localStorage: tabSessionStorage('sb-$projectRef-auth-token')),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
