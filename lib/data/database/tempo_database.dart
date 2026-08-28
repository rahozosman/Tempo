import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/diagnostics/tempo_log.dart';
import 'category_dao.dart';
import 'focus_dao.dart';
import 'limits_dao.dart';
import 'settings_dao.dart';
import 'usage_dao.dart';

/// Tempo's local database.
///
/// Everything the app records lives in one SQLite file in the platform's
/// application-support folder. Nothing is written anywhere else, and nothing
/// leaves the machine.
class TempoDatabase {
  TempoDatabase._(this._database, this.path)
    : usage = UsageDao(_database),
      settings = SettingsDao(_database),
      categories = CategoryDao(_database),
      limits = LimitsDao(_database),
      focus = FocusDao(_database);

  final Database _database;

  /// Where the file lives, shown in Settings.
  final String path;

  final UsageDao usage;
  final SettingsDao settings;
  final CategoryDao categories;
  final LimitsDao limits;
  final FocusDao focus;

  static const int schemaVersion = 3;
  static const String fileName = 'tempo.db';

  /// Opens the database, creating it on first run.
  ///
  /// Returns null when the file cannot be opened at all — a read-only disk, a
  /// corrupted file, a missing folder. The interface then shows its storage
  /// error rather than pretending to have data.
  static Future<TempoDatabase?> open({String? overridePath}) async {
    try {
      sqfliteFfiInit();
      final String file = overridePath ?? await _defaultPath();
      final Database database = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: _configure,
          onCreate: _create,
          onUpgrade: _upgrade,
        ),
      );
      return TempoDatabase._(database, file);
    } on Object catch (error, stack) {
      TempoLog.error('the database could not be opened', error, stack);
      return null;
    }
  }

  static Future<String> _defaultPath() async {
    final Directory directory = await getApplicationSupportDirectory();
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return p.join(directory.path, fileName);
  }

  static Future<void> _configure(Database database) async {
    // Write-ahead logging keeps the tracking engine's small, frequent writes
    // from blocking the screens reading alongside them.
    await database.execute('PRAGMA journal_mode = WAL');
    await database.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _create(Database database, int version) async {
    final Batch batch = database.batch();

    // Every measured stretch, exactly as it happened.
    batch.execute('''
      CREATE TABLE usage_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        application_id TEXT NOT NULL,
        application_name TEXT NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL,
        day TEXT NOT NULL,
        platform TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_sessions_day ON usage_sessions(day)');
    batch.execute(
      'CREATE INDEX idx_sessions_app ON usage_sessions(application_id, day)',
    );

    // One row per day, rebuilt from the sessions it contains. The screens read
    // these rather than walking thousands of sessions.
    batch.execute('''
      CREATE TABLE daily_summaries (
        day TEXT PRIMARY KEY,
        active_seconds INTEGER NOT NULL DEFAULT 0,
        idle_seconds INTEGER NOT NULL DEFAULT 0,
        session_count INTEGER NOT NULL DEFAULT 0,
        longest_session_seconds INTEGER NOT NULL DEFAULT 0,
        hourly_minutes TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    // One row per application per day.
    batch.execute('''
      CREATE TABLE application_summaries (
        day TEXT NOT NULL,
        application_id TEXT NOT NULL,
        application_name TEXT NOT NULL,
        seconds INTEGER NOT NULL,
        PRIMARY KEY (day, application_id)
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_app_summaries_app '
      'ON application_summaries(application_id)',
    );

    // Where an application belongs, when the default guess was wrong.
    batch.execute(_categoriesTable);

    // A daily ceiling for one application, when someone has set one.
    batch.execute(_limitsTable);

    // Blocks of deliberate work, and how much of each one stayed that way.
    batch.execute(_focusTable);
    batch.execute(_focusIndex);

    // Preferences, so a choice survives a restart.
    batch.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  static const String _categoriesTable = '''
      CREATE TABLE IF NOT EXISTS application_categories (
        application_id TEXT PRIMARY KEY,
        category TEXT NOT NULL
      )
    ''';

  static const String _limitsTable = '''
      CREATE TABLE IF NOT EXISTS application_limits (
        application_id TEXT PRIMARY KEY,
        minutes INTEGER NOT NULL
      )
    ''';

  static const String _focusTable = '''
      CREATE TABLE IF NOT EXISTS focus_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        target_seconds INTEGER NOT NULL,
        focused_seconds INTEGER NOT NULL,
        day TEXT NOT NULL
      )
    ''';

  static const String _focusIndex =
      'CREATE INDEX IF NOT EXISTS idx_focus_day ON focus_sessions(day)';

  /// Migrations run in order, and each one is safe to meet twice.
  ///
  ///  * **2** — application categories.
  ///  * **3** — daily limits, and focus blocks.
  static Future<void> _upgrade(
    Database database,
    int from,
    int to,
  ) async {
    if (from < 2) {
      await database.execute(_categoriesTable);
    }
    if (from < 3) {
      await database.execute(_limitsTable);
      await database.execute(_focusTable);
      await database.execute(_focusIndex);
    }
  }

  Future<void> close() => _database.close();
}
