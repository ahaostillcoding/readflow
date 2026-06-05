import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/sidebar_item_preference.dart';

class SidebarRepository {
  SidebarRepository(this._database);

  static const preferenceKey = 'sidebar_preferences';

  final AppDatabase _database;

  Future<List<SidebarItemPreference>> getItems({
    required List<String> categoryNames,
  }) async {
    final db = await _database.instance;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [preferenceKey],
      limit: 1,
    );
    final saved = rows.isEmpty ? null : rows.first['value'] as String?;
    final savedItems = _decode(saved);
    final merged = <String, SidebarItemPreference>{
      for (final item in savedItems) item.id: item,
    };

    final defaults = _defaultItems(categoryNames);
    final allowedIds = defaults.map((item) => item.id).toSet();
    merged.removeWhere((id, _) => !allowedIds.contains(id));

    var maxOrder = merged.values.fold<int>(
      -1,
      (value, item) => item.sortOrder > value ? item.sortOrder : value,
    );
    for (final item in defaults) {
      merged.putIfAbsent(item.id, () => item.copyWith(sortOrder: ++maxOrder));
    }

    final items = merged.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [
      for (var i = 0; i < items.length; i++) items[i].copyWith(sortOrder: i),
    ];
  }

  Future<void> saveItems(List<SidebarItemPreference> items) async {
    final db = await _database.instance;
    final normalized = [
      for (var i = 0; i < items.length; i++) items[i].copyWith(sortOrder: i),
    ];
    await db.insert(
      'app_settings',
      {
        'key': preferenceKey,
        'value': jsonEncode(normalized.map((item) => item.toJson()).toList()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  List<SidebarItemPreference> _decode(String? saved) {
    if (saved == null || saved.isEmpty) return const [];
    final decoded = jsonDecode(saved);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map)
          if (SidebarItemPreference.fromJson(Map<String, Object?>.from(item))
              case final SidebarItemPreference preference)
            preference,
    ];
  }

  List<SidebarItemPreference> _defaultItems(List<String> categoryNames) {
    final items = <SidebarItemPreference>[];
    for (var i = 0; i < defaultSidebarPageKeys.length; i++) {
      items.add(
        SidebarItemPreference(
          type: SidebarItemType.page,
          key: defaultSidebarPageKeys[i],
          visible: true,
          sortOrder: i,
        ),
      );
    }
    for (final category in categoryNames) {
      items.add(
        SidebarItemPreference(
          type: SidebarItemType.category,
          key: category,
          visible: true,
          sortOrder: items.length,
        ),
      );
    }
    return items;
  }
}

const defaultSidebarPageKeys = [
  'home',
  'feeds',
  'saved',
  'search',
  'recommended',
  'novels',
  'movies',
  'settings',
];
