import 'dart:math';

import 'package:digital_id/core/utils/sa_id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('luhnCheckDigit', () {
    test('matches a known-good SA ID checksum', () {
      // 8001015009087 is a commonly-cited valid example SA ID number.
      expect(luhnCheckDigit('800101500908'), 7);
    });

    test('is deterministic for the same input', () {
      expect(luhnCheckDigit('920304123456'), luhnCheckDigit('920304123456'));
    });
  });

  group('generateSAIdNumber', () {
    test('produces a 13-digit numeric string', () {
      final id = generateSAIdNumber(dateOfBirth: DateTime(1995, 7, 21), gender: SaIdGender.male);
      expect(id.length, 13);
      expect(RegExp(r'^\d{13}$').hasMatch(id), isTrue);
    });

    test('embeds the date of birth in digits 1-6', () {
      final dob = DateTime(1988, 12, 3);
      final id = generateSAIdNumber(dateOfBirth: dob, gender: SaIdGender.female);
      expect(id.substring(0, 6), '881203');
    });

    test('female sequence (digits 7-10) is always 0000-4999', () {
      final rnd = Random(42);
      for (var i = 0; i < 200; i++) {
        final id = generateSAIdNumber(
          dateOfBirth: DateTime(2000, 1, 1),
          gender: SaIdGender.female,
          random: rnd,
        );
        final seq = int.parse(id.substring(6, 10));
        expect(seq, inInclusiveRange(0, 4999));
      }
    });

    test('male sequence (digits 7-10) is always 5000-9999', () {
      final rnd = Random(7);
      for (var i = 0; i < 200; i++) {
        final id = generateSAIdNumber(
          dateOfBirth: DateTime(2000, 1, 1),
          gender: SaIdGender.male,
          random: rnd,
        );
        final seq = int.parse(id.substring(6, 10));
        expect(seq, inInclusiveRange(5000, 9999));
      }
    });

    test('citizenship digit (11) is 0 for SA citizens', () {
      final id = generateSAIdNumber(
        dateOfBirth: DateTime(1990, 5, 5),
        gender: SaIdGender.male,
        citizenshipStatus: 'citizen',
      );
      expect(id[10], '0');
    });

    test('citizenship digit (11) is 1 for non-citizens', () {
      final id = generateSAIdNumber(
        dateOfBirth: DateTime(1990, 5, 5),
        gender: SaIdGender.male,
        citizenshipStatus: 'permanent_resident',
      );
      expect(id[10], '1');
    });

    test('deprecated digit (12) is always 8 or 9', () {
      final rnd = Random(3);
      for (var i = 0; i < 100; i++) {
        final id = generateSAIdNumber(dateOfBirth: DateTime(1970, 1, 1), gender: SaIdGender.male, random: rnd);
        expect(['8', '9'], contains(id[11]));
      }
    });

    test('generated ID always passes Luhn validation', () {
      final rnd = Random(99);
      for (var i = 0; i < 500; i++) {
        final id = generateSAIdNumber(
          dateOfBirth: DateTime(1960 + rnd.nextInt(60), 1 + rnd.nextInt(12), 1 + rnd.nextInt(28)),
          gender: rnd.nextBool() ? SaIdGender.male : SaIdGender.female,
          random: rnd,
        );
        expect(isValidSAIdNumber(id), isTrue, reason: 'generated $id failed Luhn validation');
      }
    });
  });

  group('isValidSAIdNumber', () {
    test('rejects a tampered checksum', () {
      final id = generateSAIdNumber(dateOfBirth: DateTime(1999, 9, 9), gender: SaIdGender.female);
      final tamperedLastDigit = ((int.parse(id[12]) + 1) % 10).toString();
      final tampered = id.substring(0, 12) + tamperedLastDigit;
      expect(isValidSAIdNumber(tampered), isFalse);
    });

    test('rejects wrong-length input', () {
      expect(isValidSAIdNumber('12345'), isFalse);
    });

    test('rejects non-digit input', () {
      expect(isValidSAIdNumber('12345678901ab'), isFalse);
    });
  });

  group('saIdDateOfBirth', () {
    test('round-trips the date of birth used to generate the ID', () {
      final dob = DateTime(2003, 2, 17);
      final id = generateSAIdNumber(dateOfBirth: dob, gender: SaIdGender.male);
      expect(saIdDateOfBirth(id, referenceYear: 2026), dob);
    });

    test('disambiguates 2-digit years across the century boundary', () {
      // '05' with a 2026 reference year should resolve to 2005, not 1905.
      expect(saIdDateOfBirth('050101' '0000' '08' '0', referenceYear: 2026), DateTime(2005, 1, 1));
      // '95' should resolve to 1995.
      expect(saIdDateOfBirth('950101' '0000' '08' '0', referenceYear: 2026), DateTime(1995, 1, 1));
    });
  });

  group('saIdGenderMatches', () {
    test('true for a female ID checked against female', () {
      final id = generateSAIdNumber(dateOfBirth: DateTime(1992, 4, 4), gender: SaIdGender.female);
      expect(saIdGenderMatches(id, SaIdGender.female), isTrue);
      expect(saIdGenderMatches(id, SaIdGender.male), isFalse);
    });

    test('true for a male ID checked against male', () {
      final id = generateSAIdNumber(dateOfBirth: DateTime(1992, 4, 4), gender: SaIdGender.male);
      expect(saIdGenderMatches(id, SaIdGender.male), isTrue);
      expect(saIdGenderMatches(id, SaIdGender.female), isFalse);
    });
  });
}
