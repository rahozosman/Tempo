import '../../core/utilities/tempo_dates.dart';
import '../../core/utilities/tempo_format.dart';
import '../../data/database/settings_dao.dart';
import '../../data/database/tempo_database.dart';
import '../../data/database/usage_dao.dart';
import '../../domain/analytics/analytics_repository.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/analytics/usage_aggregate.dart';
import 'notification_service.dart';

/// The one summary Tempo sends on its own: last week, once the week has turned.
///
/// It is sent at most once per week, it says only what was measured, and the
/// week it covers is stored so a restart cannot make it repeat itself.
class WeeklyDigest {
  const WeeklyDigest._();

  static Future<void> maybeSend({
    required TempoDatabase? database,
    required AnalyticsRepository repository,
    required NotificationService notifications,
    required bool enabled,
  }) async {
    if (!enabled || database == null) {
      return;
    }

    final DateTime thisMonday = TempoDates.startOfWeek(DateTime.now());
    final String week = UsageDao.dayKey(thisMonday);
    final String? sent = await database.settings.get(
      SettingsKeys.lastWeeklyDigest,
    );
    if (sent == week) {
      return;
    }

    final DateTime from = DateTime(
      thisMonday.year,
      thisMonday.month,
      thisMonday.day - 7,
    );
    final DateTime to = DateTime(
      thisMonday.year,
      thisMonday.month,
      thisMonday.day - 1,
    );
    final List<DaySummary> days = await repository.days(from, to);
    final Duration total = UsageAggregate.screenTotal(days);

    // Nothing measured last week is not worth a notification, but the week is
    // still marked so it is not reconsidered every minute.
    if (total <= Duration.zero) {
      await database.settings.set(SettingsKeys.lastWeeklyDigest, week);
      return;
    }

    int recorded = 0;
    for (final DaySummary day in days) {
      if (!day.isEmpty) {
        recorded++;
      }
    }
    final Duration average = recorded == 0
        ? Duration.zero
        : Duration(seconds: total.inSeconds ~/ recorded);

    final List<DaySummary> before = await repository.days(
      DateTime(from.year, from.month, from.day - 7),
      DateTime(from.year, from.month, from.day - 1),
    );
    final Duration previous = UsageAggregate.screenTotal(before);
    final List<AppUsage> apps = UsageAggregate.mergeApps(days);

    final StringBuffer body = StringBuffer(
      '${TempoFormat.hm(average)} a day across '
      '${TempoFormat.count(recorded, 'day')}.',
    );
    if (apps.isNotEmpty) {
      body.write(
        ' ${apps.first.name} led with ${TempoFormat.hm(apps.first.duration)}.',
      );
    }
    if (previous > Duration.zero) {
      final double change =
          (total.inSeconds - previous.inSeconds) / previous.inSeconds;
      final int percent = (change.abs() * 100).round();
      body.write(
        percent == 0
            ? ' The same as the week before.'
            : ' $percent% ${change >= 0 ? 'more' : 'less'} than the week '
                  'before.',
      );
    }

    await notifications.show(
      'Last week: ${TempoFormat.hm(total)}',
      body.toString(),
    );
    await database.settings.set(SettingsKeys.lastWeeklyDigest, week);
  }
}
