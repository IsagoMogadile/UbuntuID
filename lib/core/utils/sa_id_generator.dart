import 'dart:math';

/// Generates and validates South African ID numbers of the form
/// `YYMMDDSSSSCAZ`:
/// - `YYMMDD` (digits 1-6): date of birth.
/// - `SSSS` (digits 7-10): gender sequence -- 0000-4999 female, 5000-9999 male.
/// - `C` (digit 11): citizenship -- 0 = SA citizen, 1 = permanent resident.
/// - `A` (digit 12): deprecated race digit, historically 8 or 9.
/// - `Z` (digit 13): Luhn checksum of the preceding 12 digits.
class SaIdGender {
  static const female = 'female';
  static const male = 'male';
}

/// Generates a valid South African ID number for the given person.
///
/// [citizenshipStatus] should be `'citizen'` for an SA citizen (digit 11 =
/// `0`) or anything else (e.g. `'permanent_resident'`) for digit 11 = `1`.
String generateSAIdNumber({
  required DateTime dateOfBirth,
  required String gender,
  String citizenshipStatus = 'citizen',
  Random? random,
}) {
  final rnd = random ?? Random();

  final yy = (dateOfBirth.year % 100).toString().padLeft(2, '0');
  final mm = dateOfBirth.month.toString().padLeft(2, '0');
  final dd = dateOfBirth.day.toString().padLeft(2, '0');

  final isFemale = gender.toLowerCase() == SaIdGender.female;
  final seqMin = isFemale ? 0 : 5000;
  final seqMax = isFemale ? 4999 : 9999;
  final sequence = seqMin + rnd.nextInt(seqMax - seqMin + 1);
  final ssss = sequence.toString().padLeft(4, '0');

  final citizenshipDigit = citizenshipStatus.toLowerCase() == 'citizen' ? '0' : '1';
  final deprecatedDigit = rnd.nextBool() ? '8' : '9';

  final base12 = '$yy$mm$dd$ssss$citizenshipDigit$deprecatedDigit';
  final checkDigit = luhnCheckDigit(base12);

  return '$base12$checkDigit';
}

/// Computes the Luhn checksum digit for a string of digits, following the
/// standard algorithm used by South African ID numbers: starting from the
/// rightmost digit, every second digit is doubled (digits of the doubled
/// value summed if it exceeds 9), then the check digit is whatever brings
/// the total to the next multiple of 10.
int luhnCheckDigit(String digits) {
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    var digit = int.parse(digits[digits.length - 1 - i]);
    if (i.isEven) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
  }
  return (10 - (sum % 10)) % 10;
}

/// Validates that [idNumber] is a well-formed 13-digit SA ID number whose
/// Luhn check digit is correct.
bool isValidSAIdNumber(String idNumber) {
  if (!RegExp(r'^\d{13}$').hasMatch(idNumber)) return false;
  final base12 = idNumber.substring(0, 12);
  final checkDigit = int.parse(idNumber[12]);
  return luhnCheckDigit(base12) == checkDigit;
}

/// Extracts the date of birth encoded in an SA ID number's first 6 digits.
/// [centuryCutoffYear] disambiguates the 2-digit year: years greater than
/// this value (relative to the current century) are assumed to be in the
/// previous century.
DateTime? saIdDateOfBirth(String idNumber, {int? referenceYear}) {
  if (idNumber.length < 6) return null;
  final yy = int.tryParse(idNumber.substring(0, 2));
  final mm = int.tryParse(idNumber.substring(2, 4));
  final dd = int.tryParse(idNumber.substring(4, 6));
  if (yy == null || mm == null || dd == null) return null;
  if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;

  final currentYear = referenceYear ?? DateTime.now().year;
  final currentCentury = (currentYear ~/ 100) * 100;
  var year = currentCentury + yy;
  if (year > currentYear) year -= 100;

  return DateTime(year, mm, dd);
}

/// `true` if digit 7-10's gender sequence in [idNumber] matches [gender].
bool saIdGenderMatches(String idNumber, String gender) {
  if (idNumber.length < 10) return false;
  final sequence = int.tryParse(idNumber.substring(6, 10));
  if (sequence == null) return false;
  final isFemale = gender.toLowerCase() == SaIdGender.female;
  return isFemale ? sequence <= 4999 : sequence >= 5000;
}
