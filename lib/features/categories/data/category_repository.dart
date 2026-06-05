import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/content_type.dart';
import '../../../core/models/content_type_preference.dart';
import '../../../core/models/feed_category.dart';

class CategoryRepository {
  CategoryRepository(this._database);

  final AppDatabase _database;

  Future<List<FeedCategory>> getCategories() async {
    final db = await _database.instance;
    final rows = await db.query('categories', orderBy: 'sort_order ASC');
    return rows.map(FeedCategory.fromMap).toList();
  }

  Future<void> addCategory(String name) async {
    final value = _normalizeName(name);
    final db = await _database.instance;
    final maxRows = await db
        .rawQuery('SELECT MAX(sort_order) AS max_order FROM categories');
    final nextOrder = ((maxRows.first['max_order'] as int?) ?? -1) + 1;
    await db.insert('categories', {'name': value, 'sort_order': nextOrder});
  }

  Future<void> renameCategory(FeedCategory category, String name) async {
    final value = _normalizeName(name);
    if (category.name == 'Other') {
      throw StateError('Other cannot be renamed.');
    }
    final db = await _database.instance;
    await db.transaction((txn) async {
      await txn.update(
        'categories',
        {'name': value},
        where: 'id = ?',
        whereArgs: [category.id],
      );
      await txn.update(
        'feeds',
        {'category': value, 'updated_at': DateTime.now().toIso8601String()},
        where: 'category = ?',
        whereArgs: [category.name],
      );
    });
  }

  Future<void> deleteCategory(FeedCategory category) async {
    if (category.name == 'Other') {
      throw StateError('Other cannot be deleted.');
    }
    final db = await _database.instance;
    await db.transaction((txn) async {
      await txn.update(
        'feeds',
        {'category': 'Other', 'updated_at': DateTime.now().toIso8601String()},
        where: 'category = ?',
        whereArgs: [category.name],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [category.id]);
    });
    await _normalizeSortOrder();
  }

  Future<void> moveCategory(FeedCategory category, int direction) async {
    final items = await getCategories();
    final index = items.indexWhere((item) => item.id == category.id);
    final targetIndex = index + direction;
    if (index < 0 || targetIndex < 0 || targetIndex >= items.length) return;
    final db = await _database.instance;
    final current = items[index];
    final target = items[targetIndex];
    await db.transaction((txn) async {
      await txn.update('categories', {'sort_order': target.sortOrder},
          where: 'id = ?', whereArgs: [current.id]);
      await txn.update('categories', {'sort_order': current.sortOrder},
          where: 'id = ?', whereArgs: [target.id]);
    });
  }

  Future<List<ContentTypePreference>> getContentTypePreferences() async {
    final db = await _database.instance;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['content_type_preferences'],
      limit: 1,
    );
    final saved = rows.isEmpty ? null : rows.first['value'] as String?;
    final preferences = <ContentType, ContentTypePreference>{};
    if (saved != null && saved.isNotEmpty) {
      final decoded = jsonDecode(saved);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final preference =
                ContentTypePreference.fromJson(Map<String, Object?>.from(item));
            if (preference != null) preferences[preference.type] = preference;
          }
        }
      }
    }

    for (final type in ContentType.values) {
      preferences.putIfAbsent(
        type,
        () => ContentTypePreference(
            type: type, visible: true, sortOrder: type.index),
      );
    }
    final items = preferences.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (var index = 0; index < items.length; index++) {
      items[index] = items[index].copyWith(sortOrder: index);
    }
    return items;
  }

  Future<void> saveContentTypePreferences(
      List<ContentTypePreference> items) async {
    final normalized = [
      for (var i = 0; i < items.length; i++) items[i].copyWith(sortOrder: i),
    ];
    final db = await _database.instance;
    await db.insert(
      'app_settings',
      {
        'key': 'content_type_preferences',
        'value': jsonEncode(normalized.map((item) => item.toJson()).toList()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _normalizeSortOrder() async {
    final items = await getCategories();
    final db = await _database.instance;
    final batch = db.batch();
    for (var i = 0; i < items.length; i++) {
      batch.update('categories', {'sort_order': i},
          where: 'id = ?', whereArgs: [items[i].id]);
    }
    await batch.commit(noResult: true);
  }

  String _normalizeName(String name) {
    final value = name.trim();
    if (value.isEmpty) throw StateError('Category name cannot be empty.');
    return value;
  }
}
