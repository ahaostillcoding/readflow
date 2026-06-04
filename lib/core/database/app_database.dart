import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  Database? _database;

  Future<Database> get instance async {
    final existing = _database;
    if (existing != null) return existing;

    final directory = await getApplicationSupportDirectory();
    final path = p.join(directory.path, 'readflow.db');

    _database = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedCategories(db);
        await _seedSettings(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToV2(db);
        }
      },
    );

    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE feeds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        url TEXT NOT NULL UNIQUE,
        site_url TEXT,
        description TEXT,
        icon_url TEXT,
        category TEXT NOT NULL DEFAULT 'Other',
        enabled INTEGER NOT NULL DEFAULT 1,
        last_fetch_at TEXT,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feed_id INTEGER NOT NULL,
        guid TEXT NOT NULL,
        title TEXT NOT NULL,
        link TEXT NOT NULL,
        author TEXT,
        summary TEXT,
        content_html TEXT,
        image_url TEXT,
        published_at TEXT,
        fetched_at TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_later INTEGER NOT NULL DEFAULT 0,
        reading_progress REAL NOT NULL DEFAULT 0,
        ai_summary TEXT,
        ai_tags TEXT,
        full_text_status TEXT NOT NULL DEFAULT 'cached',
        content_type TEXT NOT NULL DEFAULT 'other',
        extra_json TEXT,
        FOREIGN KEY(feed_id) REFERENCES feeds(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced_at TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX entries_feed_guid_idx ON entries(feed_id, guid)',
    );
    await db
        .execute('CREATE INDEX entries_published_idx ON entries(published_at)');
    await db.execute(
        'CREATE INDEX entries_content_type_idx ON entries(content_type)');
    await db.execute(
        'CREATE INDEX entries_state_idx ON entries(is_read, is_favorite, is_later)');
    await db.execute(
        'CREATE INDEX sync_outbox_pending_idx ON sync_outbox(synced_at, created_at)');
  }

  Future<void> _upgradeToV2(Database db) async {
    await _addColumnIfMissing(
        db, 'entries', 'reading_progress', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'entries', 'ai_summary', 'TEXT');
    await _addColumnIfMissing(db, 'entries', 'ai_tags', 'TEXT');
    await _addColumnIfMissing(
        db, 'entries', 'full_text_status', "TEXT NOT NULL DEFAULT 'cached'");

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced_at TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS entries_state_idx ON entries(is_read, is_favorite, is_later)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS sync_outbox_pending_idx ON sync_outbox(synced_at, created_at)');

    await db.delete('categories');
    await _seedCategories(db);
    await db.update('feeds', {'category': 'Other'},
        where: 'category NOT IN (?, ?, ?, ?, ?, ?)',
        whereArgs: defaultCategories);
  }

  Future<void> _addColumnIfMissing(
      Database db, String table, String column, String type) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> _seedCategories(Database db) async {
    for (var i = 0; i < defaultCategories.length; i++) {
      await db.insert(
        'categories',
        {
          'name': defaultCategories[i],
          'sort_order': i,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _seedSettings(Database db) async {
    await db.insert('app_settings', {'key': 'theme_mode', 'value': 'system'});
    await db
        .insert('app_settings', {'key': 'language_mode', 'value': 'system'});
    await db.insert('app_settings', {'key': 'font_size', 'value': '16'});
    await db.insert('app_settings', {'key': 'refresh_minutes', 'value': '60'});
    await db.insert('app_settings', {'key': 'ai_enabled', 'value': 'true'});
    await db.insert('app_settings',
        {'key': 'api_base_url', 'value': 'http://localhost:8000'});
  }

  Future<void> clearEntries() async {
    final db = await instance;
    await db.delete('entries');
  }
}

const defaultCategories = [
  'News',
  'Articles',
  'WeChat',
  'Novels',
  'Movies',
  'Other'
];
