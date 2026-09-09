import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase's built-in email sender is rate-limited to only a handful of
/// emails per hour (it's meant for occasional testing, not a prototype
/// where every citizen/organisation signs up with a seeded, unreachable
/// email) -- this project's "Confirm email" setting needs to be turned off
/// in the Supabase dashboard (Authentication -> Sign In / Providers ->
/// Email -> "Confirm email") for self-activation to work at all, since none
/// of these addresses can ever actually be confirmed. Used by both citizen
/// self-registration and organisation registration, which hit the same
/// `signUp` rate limit. See docs/KNOWN_LIMITATIONS.md.
String friendlyAuthError(AuthException e) {
  final message = e.message.toLowerCase();
  if (message.contains('rate limit')) {
    return "UbuntuID's email service has hit its sending limit for now. "
        'This is expected in this prototype (test emails aren\'t real '
        'inboxes) -- ask your administrator to turn off "Confirm email" in '
        'the Supabase project settings so accounts activate instantly '
        'without needing to send an email at all.';
  }
  if (message.contains('invalid') && message.contains('email')) {
    return 'That email address was rejected by the email service. Try a '
        'different one, or ask your administrator to turn off "Confirm '
        'email" in the Supabase project settings.';
  }
  return e.message;
}
