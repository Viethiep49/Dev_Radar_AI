import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

/// One cached API response.
class CacheEntry {
  final dynamic json;
  final DateTime updatedAt;

  const CacheEntry({required this.json, required this.updatedAt});
}

/// Key/value cache of API responses (JSON), used to show data when offline.
abstract class CacheLocalDataSource {
  Future<void> put(String key, dynamic json);
  Future<CacheEntry?> get(String key);
  Future<void> remove(String key);

  /// Removes every key starting with [prefix], e.g. "collection:" after a collection changes.
  Future<void> removeByPrefix(String prefix);

  /// Removes everything (Settings -> "Xoá cache", and on logout).
  Future<void> clear();

  /// Number of cached entries (shown in Settings).
  Future<int> count();
}

/// SQLite implementation (Android / iOS).
class SqliteCacheLocalDataSource implements CacheLocalDataSource {
  final AppDatabase database;

  SqliteCacheLocalDataSource(this.database);

  Database get _db => database.db;

  @override
  Future<void> put(String key, dynamic json) async {
    await _db.insert(
      AppDatabase.cacheTable,
      {
        'key': key,
        'json': jsonEncode(json),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<CacheEntry?> get(String key) async {
    final rows = await _db.query(
      AppDatabase.cacheTable,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    try {
      return CacheEntry(
        json: jsonDecode(row['json'] as String),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      );
    } on FormatException {
      await remove(key); // corrupted row
      return null;
    }
  }

  @override
  Future<void> remove(String key) async {
    await _db.delete(AppDatabase.cacheTable, where: 'key = ?', whereArgs: [key]);
  }

  @override
  Future<void> removeByPrefix(String prefix) async {
    // Escape LIKE wildcards so "a_b:" only matches literally.
    final escaped = prefix.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
    await _db.delete(
      AppDatabase.cacheTable,
      where: r"key LIKE ? ESCAPE '\'",
      whereArgs: ['$escaped%'],
    );
  }

  @override
  Future<void> clear() async {
    await _db.delete(AppDatabase.cacheTable);
  }

  @override
  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS n FROM ${AppDatabase.cacheTable}');
    return (result.first['n'] as int?) ?? 0;
  }
}

/// In-memory implementation: used on web (no sqflite there) and in widget tests.
class MemoryCacheLocalDataSource implements CacheLocalDataSource {
  final Map<String, CacheEntry> _entries = {};

  @override
  Future<void> put(String key, dynamic json) async {
    // Round-trip through JSON so callers get the same shapes as from SQLite.
    _entries[key] = CacheEntry(json: jsonDecode(jsonEncode(json)), updatedAt: DateTime.now());
  }

  @override
  Future<CacheEntry?> get(String key) async => _entries[key];

  @override
  Future<void> remove(String key) async => _entries.remove(key);

  @override
  Future<void> removeByPrefix(String prefix) async =>
      _entries.removeWhere((key, _) => key.startsWith(prefix));

  @override
  Future<void> clear() async => _entries.clear();

  @override
  Future<int> count() async => _entries.length;
}
