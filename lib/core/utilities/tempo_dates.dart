import 'package:intl/intl.dart';

/// Calendar helpers shared by every screen.
///
/// All arithmetic goes through the [DateTime] constructor rather than
/// [Duration], so adding days stays correct across daylight-saving shifts.
class TempoDates {
  const TempoDates._();

  static DateTime startOfDay(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  /// Monday of the week containing [moment].
  static DateTime startOfWeek(DateTime moment) => DateTime(
    moment.year,
    moment.month,
    moment.day - (moment.weekday - DateTime.monday),
  );

  static DateTime startOfMonth(DateTime moment) =>
      DateTime(moment.year, moment.month);

  /// Handles leap years by asking the calendar for day zero of the next month.
  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static bool isLeapYear(int year) => daysInMonth(year, 2) == 29;

  /// Whole days from [from] to [to]. Counted in UTC so a daylight-saving
  /// change cannot round the answer.
  static int daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  static int daysInYear(int year) => isLeapYear(year) ? 366 : 365;

  static String greeting(DateTime moment) {
    final int hour = moment.hour;
    if (hour < 5) {
      return 'Good night';
    }
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 18) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  static String longDate(DateTime moment) =>
      DateFormat('EEEE, d MMMM').format(moment);

  static String monthAndYear(DateTime moment) =>
      DateFormat('MMMM yyyy').format(moment);

  /// "18 – 24 Aug", the compact form used by the week stepper.
  static String weekRangeShort(DateTime moment) {
    final DateTime start = startOfWeek(moment);
    final DateTime end = DateTime(start.year, start.month, start.day + 6);
    final String tail = DateFormat('d MMM').format(end);
    final String head = start.month == end.month
        ? DateFormat('d').format(start)
        : DateFormat('d MMM').format(start);
    return '$head – $tail';
  }

  /// "18 – 24 August" or "28 August – 3 September" across a month boundary.
  static String weekRange(DateTime moment) {
    final DateTime start = startOfWeek(moment);
    final DateTime end = DateTime(start.year, start.month, start.day + 6);
    final String tail = DateFormat('d MMMM').format(end);
    final String head = start.month == end.month
        ? DateFormat('d').format(start)
        : DateFormat('d MMMM').format(start);
    return '$head – $tail';
  }
}
