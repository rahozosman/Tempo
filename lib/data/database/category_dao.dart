import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/analytics/app_category.dart';

/// Where an application belongs, when the default guess was wrong.
///
/// Only the corrections are stored. Everything else falls back to
/// [AppCategoryDefaults], so the table stays small and a better default set in
/// a later version reaches applications nobody has touched.
class CategoryDao {
  const CategoryDao(this._database);

  final Database _database;

  static const String table = 'application_categories';

  Future<Map<String, AppCategory>> overrides() async {
    final List<Map<String, Object?>> rows = await _database.query(table);
    return <String, AppCategory>{
      for (final Map<String, Object?> row in rows)
        row['application_id']! as String: AppCategory.fromName(
          row['category'] as String?,
        ),
    };
  }

  Future<void> set(String applicationId, AppCategory category) =>
      _database.insert(table, <String, Object?>{
        'application_id': applicationId,
        'category': category.name,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  /// Returns the application to whatever Tempo would have guessed.
  Future<void> clear(String applicationId) => _database.delete(
    table,
    where: 'application_id = ?',
    whereArgs: <Object?>[applicationId],
  );
}
