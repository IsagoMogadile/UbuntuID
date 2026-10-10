import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final _dateFormat = DateFormat('d MMM y');
  static final _dateTimeFormat = DateFormat('d MMM y, HH:mm');
  static final _currencyFormat = NumberFormat.currency(locale: 'en_ZA', symbol: 'R');

  // Supabase timestamps parse as UTC; show them in the viewer's local time
  // (e.g. 14:05 SAST, not 12:05). Date-only values are already local.
  static String date(DateTime value) => _dateFormat.format(value.toLocal());

  static String dateTime(DateTime value) => _dateTimeFormat.format(value.toLocal());

  static String currencyZar(num value) => _currencyFormat.format(value);

  /// Strips the spaces people type into SA ID numbers, so
  /// "030418 2723 09 4" searches as "0304182723094".
  static String compactIdNumber(String value) => value.replaceAll(RegExp(r'\s'), '');
}
