import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../core/models/content_type.dart';
import '../../../core/models/entry.dart';

class EntryRepository {
  EntryRepository(this._database);

  final AppDatabase _database;

  Future<List<Entry>> getEntries({
    String? category,
    int? feedId,
    bool unreadOnly = false,
    bool favoriteOnly = false,
    bool laterOnly = false,
    String? query,
    ContentType? contentType,
  }) async {
    final db = await _database.instance;
    final where = <String>[];
    final args = <Object?>[];

    if (category != null && category != 'All') {
      where.add('f.category = ?');
      args.add(category);
    }
    if (feedId != null) {
      where.add('e.feed_id = ?');
      args.add(feedId);
    }
    if (unreadOnly) where.add('e.is_read = 0');
    if (favoriteOnly) where.add('e.is_favorite = 1');
    if (laterOnly) where.add('e.is_later = 1');
    if (contentType != null) {
      where.add('e.content_type = ?');
      args.add(contentType.name);
    }
    if (query != null && query.trim().isNotEmpty) {
      where.add(
          '(e.title LIKE ? OR e.summary LIKE ? OR e.content_html LIKE ? OR e.ai_summary LIKE ? OR e.ai_tags LIKE ? OR f.title LIKE ?)');
      final value = '%${query.trim()}%';
      args.addAll([value, value, value, value, value, value]);
    }

    final rows = await db.rawQuery('''
      SELECT e.*, f.title AS source_name, f.category AS category
      FROM entries e
      JOIN feeds f ON f.id = e.feed_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY COALESCE(e.published_at, e.fetched_at) DESC
      LIMIT 500
    ''', args);

    return rows.map(Entry.fromMap).toList();
  }

  Future<List<Entry>> getRecommendedEntries() async {
    final db = await _database.instance;
    final rows = await db.rawQuery('''
      WITH signals AS (
        SELECT feed_id, category
        FROM entries e
        JOIN feeds f ON f.id = e.feed_id
        WHERE e.is_favorite = 1 OR e.is_later = 1
        GROUP BY feed_id, category
      )
      SELECT e.*, f.title AS source_name, f.category AS category
      FROM entries e
      JOIN feeds f ON f.id = e.feed_id
      LEFT JOIN signals s ON s.feed_id = e.feed_id OR s.category = f.category
      WHERE e.is_read = 0
      ORDER BY CASE WHEN s.feed_id IS NULL THEN 1 ELSE 0 END,
               COALESCE(e.published_at, e.fetched_at) DESC
      LIMIT 100
    ''');
    return rows.map(Entry.fromMap).toList();
  }

  Future<Entry?> getEntry(int id) async {
    final db = await _database.instance;
    final rows = await db.rawQuery('''
      SELECT e.*, f.title AS source_name, f.category AS category
      FROM entries e
      JOIN feeds f ON f.id = e.feed_id
      WHERE e.id = ?
      LIMIT 1
    ''', [id]);
    if (rows.isEmpty) return null;
    return Entry.fromMap(rows.first);
  }

  Future<void> markRead(int id, bool isRead) async {
    final db = await _database.instance;
    await db.update('entries', {'is_read': isRead ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
    await _enqueueChange(
        'entry', id.toString(), 'mark_read', {'isRead': isRead});
  }

  Future<void> setFavorite(int id, bool isFavorite) async {
    final db = await _database.instance;
    await db.update('entries', {'is_favorite': isFavorite ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
    await _enqueueChange(
        'entry', id.toString(), 'set_favorite', {'isFavorite': isFavorite});
  }

  Future<void> setLater(int id, bool isLater) async {
    final db = await _database.instance;
    await db.update('entries', {'is_later': isLater ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
    await _enqueueChange(
        'entry', id.toString(), 'set_later', {'isLater': isLater});
  }

  Future<void> setReadingProgress(int id, double progress) async {
    final normalized = progress.clamp(0, 1).toDouble();
    final db = await _database.instance;
    await db.update('entries', {'reading_progress': normalized},
        where: 'id = ?', whereArgs: [id]);
    await _enqueueChange(
        'entry', id.toString(), 'reading_progress', {'progress': normalized});
  }

  Future<void> saveAiMetadata(int id,
      {String? summary, List<String>? tags}) async {
    final db = await _database.instance;
    await db.update(
      'entries',
      {
        if (summary != null) 'ai_summary': summary,
        if (tags != null) 'ai_tags': tags.join(','),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _enqueueChange(String entityType, String entityId, String action,
      Map<String, Object?> payload) async {
    final db = await _database.instance;
    await db.insert('sync_outbox', {
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'synced_at': null,
      'retry_count': 0,
      'last_error': null,
    });
  }
}
