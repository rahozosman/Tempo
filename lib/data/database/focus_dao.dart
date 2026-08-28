import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/tracking/focus_block.dart';
import 'usage_dao.dart';

/// Blocks of deliberate work, and how much of each one stayed that way.
///
/// A block is written once, when it ends. Nothing is stored while one is
/// running, so an interrupted session leaves nothing behind.
class FocusDao {
  const FocusDao(this._database);

  final Database _database;

  static const String table = 'focus_sessions';

  Future<int> add(FocusBlock block) => _database.insert(table, <String, Object?>{
    'start_ms': block.start.millisecondsSinceEpoch,
    'end_ms': block.end.millisecondsSinceEpoch,
    'target_seconds': block.target.inSeconds,
    'focused_seconds': block.focused.inSeconds,
    'day': UsageDao.dayKey(block.day),
  });

  /// The most recent blocks, newest first.
  Future<List<FocusBlock>> recent({int limit = 8}) async {
    final List<Map<String, Object?>> rows = await _database.query(
      table,
      orderBy: 'start_ms DESC',
      limit: limit,
    );
    return <FocusBlock>[
      for (final Map<String, Object?> row in rows) _fromRow(row),
    ];
  }

  /// Everything focused on one day, for the day's own totals.
  Future<List<FocusBlock>> on(DateTime day) async {
    final List<Map<String, Object?>> rows = await _database.query(
      table,
      where: 'day = ?',
      whereArgs: <Object?>[UsageDao.dayKey(day)],
      orderBy: 'start_ms ASC',
    );
    return <FocusBlock>[
      for (final Map<String, Object?> row in rows) _fromRow(row),
    ];
  }

  static FocusBlock _fromRow(Map<String, Object?> row) => FocusBlock(
    id: row['id'] as int?,
    start: DateTime.fromMillisecondsSinceEpoch(row['start_ms']! as int),
    end: DateTime.fromMillisecondsSinceEpoch(row['end_ms']! as int),
    target: Duration(seconds: row['target_seconds']! as int),
    focused: Duration(seconds: row['focused_seconds']! as int),
  );
}
