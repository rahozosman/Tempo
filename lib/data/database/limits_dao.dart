import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A daily ceiling for one application.
///
/// Only applications with a limit are stored, so an empty table means nobody
/// has asked Tempo to watch anything in particular.
class LimitsDao {
  const LimitsDao(this._database);

  final Database _database;

  static const String table = 'application_limits';

  Future<Map<String, Duration>> all() async {
    final List<Map<String, Object?>> rows = await _database.query(table);
    return <String, Duration>{
      for (final Map<String, Object?> row in rows)
        row['application_id']! as String: Duration(
          minutes: row['minutes']! as int,
        ),
    };
  }

  Future<void> set(String applicationId, Duration limit) => _database.insert(
    table,
    <String, Object?>{
      'application_id': applicationId,
      'minutes': limit.inMinutes,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> clear(String applicationId) => _database.delete(
    table,
    where: 'application_id = ?',
    whereArgs: <Object?>[applicationId],
  );
}
