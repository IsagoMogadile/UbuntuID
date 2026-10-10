import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final _dateFormat = DateFormat('d MMM y');
  static final _dateTimeFormat = DateFormat('d MMM y, HH:mm');
  static final _currencyFormat = NumberFormat.currency(locale: 'en_ZA', symbol: 'R');

  /// South African Standard Time is UTC+2 all year (no daylight saving).
  static const _sastOffset = Duration(hours: 2);

  /// Supabase timestamps parse as UTC; show them in SAST whatever the
  /// viewer's device is set to (14:05 SAST, not 12:05 UTC), so an audit
  /// trail reads the same on every screen. Date-only values parse as local
  /// midnight and are shown as they are.
  static DateTime toSast(DateTime value) =>
      value.isUtc ? DateTime.fromMillisecondsSinceEpoch(value.add(_sastOffset).millisecondsSinceEpoch, isUtc: true) : value;

  static String date(DateTime value) => _dateFormat.format(toSast(value));

  static String dateTime(DateTime value) => _dateTimeFormat.format(toSast(value));

  static String currencyZar(num value) => _currencyFormat.format(value);

  /// Strips the spaces people type into SA ID numbers, so
  /// "030418 2723 09 4" searches as "0304182723094".
  static String compactIdNumber(String value) => value.replaceAll(RegExp(r'\s'), '');
}
