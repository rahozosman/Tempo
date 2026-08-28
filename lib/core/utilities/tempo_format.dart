import 'package:intl/intl.dart';

/// Every number Tempo shows is formatted here, so a duration reads the same
/// way on every screen.
class TempoFormat {
  const TempoFormat._();

  /// `6h 42m`, `42m`, `0m`.
  static String hm(Duration value) {
    final int minutes = value.inMinutes;
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    if (hours == 0) {
      return '${rest}m';
    }
    return '${hours}h ${rest}m';
  }

  /// `6 hours 42 minutes`, for tooltips and semantics.
  static String hmSpoken(Duration value) {
    final int minutes = value.inMinutes;
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    final List<String> parts = <String>[
      if (hours > 0) '$hours ${hours == 1 ? 'hour' : 'hours'}',
      if (rest > 0 || hours == 0) '$rest ${rest == 1 ? 'minute' : 'minutes'}',
    ];
    return parts.join(' ');
  }

  static String count(int value, String singular, [String? plural]) =>
      '$value ${value == 1 ? singular : (plural ?? '${singular}s')}';

  static String percent(double fraction) =>
      '${(fraction * 100).round().clamp(0, 100)}%';

  /// `+18%` / `-8%`. Never coloured as good or bad by itself.
  static String signedPercent(double change) {
    final int rounded = (change * 100).round();
    return '${rounded >= 0 ? '+' : '-'}${rounded.abs()}%';
  }

  /// Locale-aware clock, `14:32` or `2:32 PM`.
  static String clock(DateTime moment) => DateFormat.jm().format(moment);

  /// Locale-aware hour label used by the day timeline, `14` or `2 PM`.
  static String hourLabel(int hour) =>
      DateFormat.j().format(DateTime(2024, 1, 1, hour));

  /// `Mon`, for chart axes.
  static String weekdayShort(DateTime date) => DateFormat.E().format(date);

  /// `Tue 12`, for compact date references.
  static String dayShort(DateTime date) => DateFormat('EEE d').format(date);

  /// `18 August`, for headings.
  static String monthDay(DateTime date) => DateFormat('d MMMM').format(date);

  /// `Monday 18 August`, for tooltips.
  static String dayLong(DateTime date) =>
      DateFormat('EEEE d MMMM').format(date);
}
