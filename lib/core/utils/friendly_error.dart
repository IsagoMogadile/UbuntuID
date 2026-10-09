import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns any error into one plain sentence a user can act on. Technical
/// details (SQL, stack traces, HTTP codes) are never shown; messages our
/// own database functions raise on purpose ("The end date cannot be before
/// the start date.") are passed through, since they were written for users.
String friendlyError(Object error) {
  if (error is AuthException) return friendlyAuthMessage(error.message);

  if (error is PostgrestException) {
    final message = error.message.trim();
    switch (error.code) {
      case 'P0001': // raise exception '...' in our own functions
        return _sentence(message);
      case '42501':
        return "You don't have permission to do this.";
      case '23505':
        return 'This already exists, so it was not saved again.';
      case '23503':
        return 'This is linked to other records, so it cannot be changed or removed.';
      case '23502':
      case '23514':
      case '22P02':
      case '22007':
      case '22008':
        return 'Some of the details are not valid. Check them and try again.';
      case '57014':
        return 'This took too long to load. Please try again.';
      case 'PGRST116':
        return 'We could not find that record. It may have been removed.';
    }
    if (message.toLowerCase().contains('row-level security') || message.toLowerCase().contains('permission denied')) {
      return "You don't have permission to do this.";
    }
    return _generic;
  }

  if (error is StorageException) return 'The file could not be saved or opened. Please try again.';
  if (error is TimeoutException) return 'This is taking longer than expected. Check your connection and try again.';
  if (error is FormatException) return _sentence(error.message);

  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('failed to fetch') ||
      text.contains('xmlhttprequest') ||
      text.contains('network') ||
      text.contains('connection')) {
    return 'You seem to be offline. Check your internet connection and try again.';
  }
  return _generic;
}

/// Sign-in, registration and password messages in plain words.
String friendlyAuthMessage(String raw) {
  final message = raw.toLowerCase();
  if (message.contains('invalid login credentials')) return 'The email address or password is incorrect.';
  if (message.contains('email not confirmed')) return 'Please confirm your email address before signing in.';
  if (message.contains('already registered') || message.contains('already been registered')) {
    return 'An account with this email address already exists. Try signing in instead.';
  }
  if (message.contains('rate limit') || message.contains('too many')) {
    return 'Too many attempts. Please wait a few minutes and try again.';
  }
  if (message.contains('password') && (message.contains('at least') || message.contains('weak'))) {
    return 'Choose a longer password: at least 8 characters.';
  }
  if (message.contains('same password') || message.contains('different from the old')) {
    return 'Your new password must be different from your current one.';
  }
  if (message.contains('invalid') && message.contains('email')) return 'Enter a valid email address.';
  if (message.contains('expired') || message.contains('invalid') && message.contains('token')) {
    return 'This link has expired. Please request a new one.';
  }
  if (message.contains('network') || message.contains('fetch')) {
    return 'You seem to be offline. Check your internet connection and try again.';
  }
  return 'We could not sign you in right now. Please try again.';
}

const _generic = 'Something went wrong on our side. Please try again.';

String _sentence(String text) {
  final t = text.trim();
  if (t.isEmpty) return _generic;
  return RegExp(r'[.!?]$').hasMatch(t) ? t : '$t.';
}
