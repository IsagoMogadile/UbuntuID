import 'dart:async';

import 'package:digital_id/core/utils/friendly_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('friendlyError', () {
    test('passes through messages our own database functions raise on purpose', () {
      const e = PostgrestException(message: 'The end date cannot be before the start date', code: 'P0001');
      expect(friendlyError(e), 'The end date cannot be before the start date.');
    });

    test('never shows raw database errors', () {
      const e = PostgrestException(
        message: 'duplicate key value violates unique constraint "citizens_id_number_key"',
        code: '23505',
      );
      expect(friendlyError(e), 'This already exists, so it was not saved again.');
      expect(friendlyError(e), isNot(contains('constraint')));
    });

    test('explains permission problems plainly', () {
      const e = PostgrestException(message: 'new row violates row-level security policy for table "x"', code: '42501');
      expect(friendlyError(e), "You don't have permission to do this.");
    });

    test('recognises a dropped connection', () {
      expect(friendlyError(Exception('ClientException: Failed to fetch')), contains('offline'));
    });

    test('recognises a timeout', () {
      expect(friendlyError(TimeoutException('slow')), contains('longer than expected'));
    });

    test('falls back to a generic sentence for anything unknown', () {
      expect(friendlyError(StateError('Bad state: No element')), 'Something went wrong on our side. Please try again.');
    });
  });

  group('friendlyAuthMessage', () {
    test('wrong email or password', () {
      expect(friendlyAuthMessage('Invalid login credentials'), 'The email address or password is incorrect.');
    });

    test('rate limits ask the user to wait instead of mentioning project settings', () {
      final message = friendlyAuthMessage('Email rate limit exceeded');
      expect(message, contains('wait'));
      expect(message, isNot(contains('Supabase')));
    });

    test('unknown auth errors stay generic', () {
      expect(friendlyAuthMessage('some internal gotrue failure'), 'We could not sign you in right now. Please try again.');
    });
  });
}
