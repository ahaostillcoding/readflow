import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class SyncRepository {
  SyncRepository(this._database, this._dio);

  final AppDatabase _database;
  final Dio _dio;

  Future<String> register({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      _join(baseUrl, '/auth/register'),
      data: {'email': email.trim(), 'password': password},
    );
    return response.data?['access_token'] as String;
  }

  Future<String> login({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      _join(baseUrl, '/auth/login'),
      data: {'username': email.trim(), 'password': password},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return response.data?['access_token'] as String;
  }

  Future<SyncResult> sync({
    required String baseUrl,
    required String token,
  }) async {
    final db = await _database.instance;
    final deviceKey = await _deviceKey(db);
    await _registerDevice(baseUrl: baseUrl, token: token, deviceKey: deviceKey);

    final pending = await db.query(
      'sync_outbox',
      where: 'synced_at IS NULL',
      orderBy: 'created_at ASC',
      limit: 200,
    );

    if (pending.isEmpty) {
      await _pull(baseUrl: baseUrl, token: token, db: db);
      return const SyncResult(pushed: 0, pulled: 0);
    }

    final changes = pending
        .map(
          (row) => {
            'entity_type': row['entity_type'],
            'entity_id': row['entity_id'],
            'action': row['action'],
            'payload': jsonDecode(row['payload'] as String),
            'device_key': deviceKey,
          },
        )
        .toList();

    await _dio.post<void>(
      _join(baseUrl, '/sync/push'),
      data: changes,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final row in pending) {
      batch.update('sync_outbox', {'synced_at': now}, where: 'id = ?', whereArgs: [row['id']]);
    }
    await batch.commit(noResult: true);

    final pulled = await _pull(baseUrl: baseUrl, token: token, db: db);
    return SyncResult(pushed: pending.length, pulled: pulled);
  }

  Future<void> _registerDevice({
    required String baseUrl,
    required String token,
    required String deviceKey,
  }) {
    return _dio.post<void>(
      _join(baseUrl, '/auth/devices'),
      data: {
        'device_key': deviceKey,
        'name': defaultTargetPlatform.name,
        'platform': defaultTargetPlatform.name,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<int> _pull({
    required String baseUrl,
    required String token,
    required Database db,
  }) async {
    final settings = await db.query('app_settings', where: 'key = ?', whereArgs: ['sync_cursor'], limit: 1);
    final cursor = settings.isEmpty ? '0' : settings.first['value'] as String;
    final response = await _dio.get<Map<String, Object?>>(
      _join(baseUrl, '/sync/pull?cursor=$cursor'),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final nextCursor = response.data?['cursor']?.toString() ?? cursor;
    final events = response.data?['events'] as List<dynamic>? ?? const [];
    await db.insert(
      'app_settings',
      {'key': 'sync_cursor', 'value': nextCursor},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return events.length;
  }

  Future<String> _deviceKey(Database db) async {
    final rows = await db.query('app_settings', where: 'key = ?', whereArgs: ['device_key'], limit: 1);
    if (rows.isNotEmpty) return rows.first['value'] as String;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final key = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    await db.insert(
      'app_settings',
      {'key': 'device_key', 'value': key},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return key;
  }

  String _join(String baseUrl, String path) {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$trimmed$path';
  }
}

class SyncResult {
  const SyncResult({required this.pushed, required this.pulled});

  final int pushed;
  final int pulled;
}
