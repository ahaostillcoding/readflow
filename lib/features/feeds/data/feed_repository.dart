import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/feed.dart';
import 'feed_parser_service.dart';
import 'parsed_feed.dart';

class FeedRepository {
  FeedRepository(this._database, this._parser);

  final AppDatabase _database;
  final FeedParserService _parser;

  Future<List<Feed>> watchableFeeds() => getFeeds();

  Future<List<Feed>> getFeeds() async {
    final db = await _database.instance;
    final rows = await db.query('feeds', orderBy: 'category ASC, title COLLATE NOCASE ASC');
    return rows.map(Feed.fromMap).toList();
  }

  Future<ParsedFeed> previewFeed(String url, String category) {
    return _parser.fetchAndParse(url, category: category);
  }

  Future<int> addFeed({
    required String url,
    required String category,
    String? customTitle,
  }) async {
    final parsed = await _parser.fetchAndParse(url, category: category);
    final db = await _database.instance;
    final now = DateTime.now().toIso8601String();
    final feedId = await db.insert(
      'feeds',
      {
        'title': (customTitle?.trim().isNotEmpty ?? false) ? customTitle!.trim() : parsed.title,
        'url': url.trim(),
        'site_url': parsed.siteUrl,
        'description': parsed.description,
        'icon_url': parsed.iconUrl,
        'category': category,
        'enabled': 1,
        'last_fetch_at': now,
        'last_error': null,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    await _insertEntries(db, feedId, category, parsed.entries);
    await _enqueueChange('feed', feedId.toString(), 'add_feed', {
      'url': url.trim(),
      'title': (customTitle?.trim().isNotEmpty ?? false) ? customTitle!.trim() : parsed.title,
      'category': category,
    });
    return feedId;
  }

  Future<void> updateFeedTitle(int id, String title) async {
    final db = await _database.instance;
    await db.update(
      'feeds',
      {'title': title.trim(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueChange('feed', id.toString(), 'rename_feed', {'title': title.trim()});
  }

  Future<void> updateFeedCategory(int id, String category) async {
    final db = await _database.instance;
    await db.update(
      'feeds',
      {'category': category, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueChange('feed', id.toString(), 'change_category', {'category': category});
  }

  Future<void> setFeedEnabled(int id, bool enabled) async {
    final db = await _database.instance;
    await db.update(
      'feeds',
      {'enabled': enabled ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueChange('feed', id.toString(), 'set_enabled', {'enabled': enabled});
  }

  Future<void> deleteFeed(int id) async {
    final db = await _database.instance;
    await db.delete('feeds', where: 'id = ?', whereArgs: [id]);
    await _enqueueChange('feed', id.toString(), 'delete_feed', {'deleted': true});
  }

  Future<RefreshResult> refreshFeed(Feed feed) async {
    final db = await _database.instance;
    try {
      final parsed = await _parser.fetchAndParse(feed.url, category: feed.category);
      await _insertEntries(db, feed.id, feed.category, parsed.entries);
      await db.update(
        'feeds',
        {
          'title': parsed.title,
          'site_url': parsed.siteUrl,
          'description': parsed.description,
          'icon_url': parsed.iconUrl,
          'last_fetch_at': DateTime.now().toIso8601String(),
          'last_error': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [feed.id],
      );
      return RefreshResult(feedId: feed.id, success: true, newCount: parsed.entries.length);
    } catch (error) {
      await db.update(
        'feeds',
        {
          'last_fetch_at': DateTime.now().toIso8601String(),
          'last_error': error.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [feed.id],
      );
      return RefreshResult(feedId: feed.id, success: false, error: error.toString());
    }
  }

  Future<List<RefreshResult>> refreshAllFeeds() async {
    final feeds = (await getFeeds()).where((feed) => feed.enabled).toList();
    final results = <RefreshResult>[];
    for (final feed in feeds) {
      results.add(await refreshFeed(feed));
    }
    return results;
  }

  Future<void> _insertEntries(
    Database db,
    int feedId,
    String category,
    List<ParsedEntry> entries,
  ) async {
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert(
        'entries',
        {
          'feed_id': feedId,
          'guid': entry.guid,
          'title': entry.title,
          'link': entry.link,
          'author': entry.author,
          'summary': entry.summary,
          'content_html': entry.contentHtml,
          'image_url': entry.imageUrl,
          'published_at': entry.publishedAt?.toIso8601String(),
          'fetched_at': now,
          'is_read': 0,
          'is_favorite': 0,
          'is_later': 0,
          'reading_progress': 0,
          'ai_summary': null,
          'ai_tags': null,
          'full_text_status': entry.contentHtml == null ? 'summary' : 'cached',
          'content_type': entry.contentType.name,
          'extra_json': entry.extraJson,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _enqueueChange(String entityType, String entityId, String action, Map<String, Object?> payload) async {
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

class RefreshResult {
  const RefreshResult({
    required this.feedId,
    required this.success,
    this.newCount = 0,
    this.error,
  });

  final int feedId;
  final bool success;
  final int newCount;
  final String? error;
}
