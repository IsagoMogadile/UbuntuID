import 'package:digital_id/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFormatters', () {
    test('date formats without a time component', () {
      expect(AppFormatters.date(DateTime(2024, 3, 5)), '5 Mar 2024');
    });

    test('dateTime includes hours and minutes', () {
      expect(AppFormatters.dateTime(DateTime(2024, 3, 5, 14, 30)), '5 Mar 2024, 14:30');
    });

    test('currencyZar renders a Rand symbol and no fractional grants amount lost', () {
      final formatted = AppFormatters.currencyZar(2090);
      expect(formatted, contains('R'));
      expect(formatted, contains('2'));
      expect(formatted, contains('090'));
    });
  });
}
