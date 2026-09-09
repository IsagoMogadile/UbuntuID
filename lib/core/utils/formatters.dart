import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final _dateFormat = DateFormat('d MMM y');
  static final _dateTimeFormat = DateFormat('d MMM y, HH:mm');
  static final _currencyFormat = NumberFormat.currency(locale: 'en_ZA', symbol: 'R');

  static String date(DateTime value) => _dateFormat.format(value);

  static String dateTime(DateTime value) => _dateTimeFormat.format(value);

  static String currencyZar(num value) => _currencyFormat.format(value);
}
