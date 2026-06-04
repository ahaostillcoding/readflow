import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

class SettingsRepository {
  SettingsRepository(this._database);

  final AppDatabase _database;

  Future<Map<String, String>> getAll() async {
    final db = await _database.instance;
    final rows = await db.query('app_settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<void> setValue(String key, String value) async {
    final db = await _database.instance;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearEntries() => _database.clearEntries();
}
