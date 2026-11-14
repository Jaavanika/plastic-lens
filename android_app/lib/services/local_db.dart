import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/scan_record.dart';
import 'scan_store.dart';

/// The part of local storage that cloud sync needs (in-memory in tests).
abstract class SyncStateStore {
  Future<String?> getSetting(String key);
  Future<void> setSetting(String key, String? value);
  Future<List<String>> tombstones();
  Future<void> addTombstone(String id);
  Future<void> removeTombstone(String id);
}

class InMemorySyncState implements SyncStateStore {
  final settings = <String, String>{};
  final deleted = <String>{};
  @override
  Future<String?> getSetting(String key) async => settings[key];
  @override
  Future<void> setSetting(String key, String? value) async => value == null ? settings.remove(key) : settings[key] = value;
  @override
  Future<List<String>> tombstones() async => deleted.toList();
  @override
  Future<void> addTombstone(String id) async => deleted.add(id);
  @override
  Future<void> removeTombstone(String id) async => deleted.remove(id);
}

/// On-device SQLite database: scans, key/value settings, learning progress.
class LocalDb implements SyncStateStore {
  LocalDb._(this.db);
  final Database db;

  static Future<LocalDb> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'plasticlens.db');
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE scans (
              id TEXT PRIMARY KEY,
              item_name TEXT NOT NULL,
              contains_plastic INTEGER,
              plastic_type TEXT,
              resin_code INTEGER,
              confidence REAL NOT NULL,
              state TEXT NOT NULL,
              model_version TEXT NOT NULL,
              image_path TEXT NOT NULL,
              created_at TEXT NOT NULL,
              llm_used INTEGER NOT NULL DEFAULT 0,
              user_verified INTEGER NOT NULL DEFAULT 0,
              in_collection INTEGER NOT NULL DEFAULT 0,
              remote_image_path TEXT,
              sync_status TEXT NOT NULL,
              updated_at TEXT,
              second_opinion TEXT
            )''');
          await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
          await db.execute('CREATE TABLE lessons_done (lesson_id TEXT PRIMARY KEY, done_at TEXT NOT NULL)');
          await db.execute('CREATE TABLE tombstones (id TEXT PRIMARY KEY)');
        },
      ),
    );
    return LocalDb._(db);
  }

  @override
  Future<String?> getSetting(String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> setSetting(String key, String? value) => value == null
      ? db.delete('settings', where: 'key = ?', whereArgs: [key])
      : db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Map<String, DateTime>> lessonsDone() async {
    final rows = await db.query('lessons_done');
    return {for (final r in rows) r['lesson_id'] as String: DateTime.parse(r['done_at'] as String)};
  }

  Future<void> markLessonDone(String id, DateTime at) => db.insert(
      'lessons_done', {'lesson_id': id, 'done_at': at.toUtc().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore);

  /// Scans deleted while offline, so sync can delete them remotely later.
  @override
  Future<List<String>> tombstones() async =>
      (await db.query('tombstones')).map((r) => r['id'] as String).toList();
  @override
  Future<void> addTombstone(String id) =>
      db.insert('tombstones', {'id': id}, conflictAlgorithm: ConflictAlgorithm.ignore);
  @override
  Future<void> removeTombstone(String id) => db.delete('tombstones', where: 'id = ?', whereArgs: [id]);

  Future<void> wipe() async {
    await db.delete('scans');
    await db.delete('lessons_done');
    await db.delete('tombstones');
    await db.delete('settings');
  }
}

class SqliteScanStorage implements ScanStorage {
  SqliteScanStorage(this._db);
  final LocalDb _db;

  @override
  Future<List<ScanRecord>> loadAll() async =>
      (await _db.db.query('scans')).map(ScanRecord.fromMap).toList();

  @override
  Future<void> upsert(ScanRecord scan) =>
      _db.db.insert('scans', scan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> delete(String id) => _db.db.delete('scans', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> clear() => _db.db.delete('scans');
}
