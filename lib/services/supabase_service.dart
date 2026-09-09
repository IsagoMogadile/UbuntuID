import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env_config.dart';

class SupabaseService {
  SupabaseService._();

  /// Must be called once, before [client] is first used (see `main.dart`).
  /// Using `Supabase.initialize` rather than constructing a bare
  /// [SupabaseClient] is what gives the app session persistence across page
  /// refreshes on Flutter Web, and automatic exchange of the password-reset
  /// email link into a recovery session before `ResetPasswordScreen` runs.
  static Future<void> initialize() {
    return Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
