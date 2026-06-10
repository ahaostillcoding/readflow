import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/feed.dart';
import 'feed_parser_service.dart';
import 'full_text_service.dart';
import 'parsed_feed.dart';

class FeedRepository {
  FeedRepository(this._database, this._parser, this._fullTextService);

  final AppDatabase _database;
  final FeedParserService _parser;
  final FullTextService _fullTextService;

  Future<List<Feed>> watchableFeeds() => getFeeds();

  Future<List<Feed>> getFeeds() async {
    final db = await _database.instance;
    final rows = await db.query('feeds',
        orderBy: 'category ASC, title COLLATE NOCASE ASC');
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
        'title': (customTitle?.trim().isNotEmpty ?? false)
            ? customTitle!.trim()
            : parsed.title,
        'url': url.trim(),
        'site_url': parsed.siteUrl,
        'description': parsed.description,
        'icon_url': parsed.iconUrl,
        'category': category,
        'enabled': 1,
        'full_text_mode': 'manual',
        'full_text_selector': null,
        'full_text_exclude_selector': null,
        'full_text_last_error': null,
        'last_fetch_at': now,
        'last_error': null,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    await _upsertEntries(db, feedId, category, parsed.entries);
    await _enqueueChange('feed', feedId.toString(), 'add_feed', {
      'url': url.trim(),
      'title': (customTitle?.trim().isNotEmpty ?? false)
          ? customTitle!.trim()
          : parsed.title,
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
    await _enqueueChange(
        'feed', id.toString(), 'rename_feed', {'title': title.trim()});
  }

  Future<void> updateFeedCategory(int id, String category) async {
    final db = await _database.instance;
    await db.update(
      'feeds',
      {'category': category, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueChange(
        'feed', id.toString(), 'change_category', {'category': category});
  }

  Future<void> setFeedEnabled(int id, bool enabled) async {
    final db = await _database.instance;
    await db.update(
      'feeds',
      {
        'enabled': enabled ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String()
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueChange(
        'feed', id.toString(), 'set_enabled', {'enabled': enabled});
  }

  Future<void> updateFullTextSettings(
    int id, {
    required String mode,
    String? selector,
    String? excludeSelector,
  }) async {
    final db = await _database.instance;
    await db.update(
      'feeds',
      {
        'full_text_mode': mode,
        'full_text_selector': _emptyToNull(selector),
        'full_text_exclude_selector': _emptyToNull(excludeSelector),
        'full_text_last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueChange('feed', id.toString(), 'full_text_settings', {
      'mode': mode,
      'selector': _emptyToNull(selector),
      'excludeSelector': _emptyToNull(excludeSelector),
    });
  }

  Future<void> deleteFeed(int id) async {
    final db = await _database.instance;
    await db.delete('feeds', where: 'id = ?', whereArgs: [id]);
    await _enqueueChange(
        'feed', id.toString(), 'delete_feed', {'deleted': true});
  }

  Future<RefreshResult> refreshFeed(Feed feed) async {
    final db = await _database.instance;
    try {
      final parsed =
          await _parser.fetchAndParse(feed.url, category: feed.category);
      final candidates =
          await _upsertEntries(db, feed.id, feed.category, parsed.entries);
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
      if (feed.fullTextMode == 'auto') {
        await _fetchFullTextForEntries(db, feed, candidates.take(10));
      }
      return RefreshResult(
          feedId: feed.id, success: true, newCount: parsed.entries.length);
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
      return RefreshResult(
          feedId: feed.id, success: false, error: error.toString());
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

  Future<List<int>> _upsertEntries(
    Database db,
    int feedId,
    String category,
    List<ParsedEntry> entries,
  ) async {
    final now = DateTime.now().toIso8601String();
    final fullTextCandidates = <int>[];
    for (final entry in entries) {
      final values = {
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
        'full_text_status': entry.fullTextStatus,
        'full_text_error': null,
        'content_type': entry.contentType.name,
        'extra_json': entry.extraJson,
      };
      final insertedId = await db.insert(
        'entries',
        values,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final id = insertedId == 0
          ? await _updateExistingEntry(db, feedId, entry, now)
          : insertedId;
      if (id != null && entry.fullTextStatus == 'feed_summary') {
        fullTextCandidates.add(id);
      }
    }
    return fullTextCandidates;
  }

  Future<int?> _updateExistingEntry(
    Database db,
    int feedId,
    ParsedEntry entry,
    String fetchedAt,
  ) async {
    final rows = await db.query(
      'entries',
      columns: ['id', 'content_html', 'full_text_status'],
      where: 'feed_id = ? AND guid = ?',
      whereArgs: [feedId, entry.guid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final id = rows.first['id'] as int;
    final currentContent = rows.first['content_html'] as String?;
    final currentStatus = rows.first['full_text_status'] as String?;
    final nextContent = entry.contentHtml;
    final shouldUpdateContent = nextContent != null &&
        _plainTextLength(nextContent) > _plainTextLength(currentContent);
    await db.update(
      'entries',
      {
        'title': entry.title,
        'link': entry.link,
        'author': entry.author,
        'summary': entry.summary,
        if (shouldUpdateContent) 'content_html': nextContent,
        if (entry.imageUrl != null) 'image_url': entry.imageUrl,
        'published_at': entry.publishedAt?.toIso8601String(),
        'fetched_at': fetchedAt,
        if (shouldUpdateContent || currentStatus == null)
          'full_text_status': entry.fullTextStatus,
        'content_type': entry.contentType.name,
        'extra_json': entry.extraJson,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<void> fetchFullTextForEntry({
    required int entryId,
    required String url,
    required String mode,
    String? selector,
    String? excludeSelector,
  }) async {
    final db = await _database.instance;
    if (mode == 'off') {
      await _markFullTextDisabled(db, entryId);
      return;
    }
    await _fetchFullTextForEntry(
      db,
      entryId,
      url,
      selector: selector,
      excludeSelector: excludeSelector,
    );
    final rows = await db.query(
      'entries',
      columns: ['full_text_status', 'full_text_error'],
      where: 'id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    if (rows.isNotEmpty && rows.first['full_text_status'] == 'failed') {
      final message = rows.first['full_text_error'] as String?;
      throw StateError(message ?? 'Full text extraction failed.');
    }
  }

  Future<void> _fetchFullTextForEntries(
    Database db,
    Feed feed,
    Iterable<int> entryIds,
  ) async {
    for (final entryId in entryIds) {
      final rows = await db.query(
        'entries',
        columns: ['link'],
        where: 'id = ?',
        whereArgs: [entryId],
        limit: 1,
      );
      if (rows.isEmpty) continue;
      await _fetchFullTextForEntry(
        db,
        entryId,
        rows.first['link'] as String,
        selector: feed.fullTextSelector,
        excludeSelector: feed.fullTextExcludeSelector,
        feedId: feed.id,
      );
    }
  }

  Future<void> _fetchFullTextForEntry(
    Database db,
    int entryId,
    String url, {
    String? selector,
    String? excludeSelector,
    int? feedId,
  }) async {
    await db.update(
      'entries',
      {'full_text_status': 'fetching', 'full_text_error': null},
      where: 'id = ?',
      whereArgs: [entryId],
    );
    try {
      final result = await _fullTextService.fetch(
        url,
        includeSelector: selector,
        excludeSelector: excludeSelector,
      );
      await db.update(
        'entries',
        {
          'content_html': result.contentHtml,
          if (result.imageUrl != null) 'image_url': result.imageUrl,
          'full_text_status': 'fetched',
          'full_text_error': null,
          'fetched_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [entryId],
      );
      if (feedId != null) {
        await db.update('feeds', {'full_text_last_error': null},
            where: 'id = ?', whereArgs: [feedId]);
      }
    } catch (error) {
      final message = error.toString();
      await db.update(
        'entries',
        {'full_text_status': 'failed', 'full_text_error': message},
        where: 'id = ?',
        whereArgs: [entryId],
      );
      if (feedId != null) {
        await db.update('feeds', {'full_text_last_error': message},
            where: 'id = ?', whereArgs: [feedId]);
      }
    }
  }

  Future<void> _markFullTextDisabled(Database db, int entryId) async {
    await db.update(
      'entries',
      {'full_text_status': 'disabled', 'full_text_error': null},
      where: 'id = ?',
      whereArgs: [entryId],
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

  int _plainTextLength(String? html) {
    if (html == null) return 0;
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .length;
  }

  String? _emptyToNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
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
