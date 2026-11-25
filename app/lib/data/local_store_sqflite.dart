import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'local_store.dart';

Future<LocalStore> openPlatformStore() => SqfliteStore.open();

/// SQLite tabanlı depo.
///
/// * `bookmarks`, `favorites`, `history` tabloları: kaydedilenler, favoriler ve okuma geçmişi
///   (içeriğin tam JSON'u saklanır; internet yokken ve haber yayından kalktığında da açılabilir).
/// * `cache_index` tablosu: önbellekteki her uç noktanın kaydedilme zamanı ve boyutu.
///
/// Uç noktaların gövdeleri (yüzlerce KB olabilir) satır yerine aynı klasördeki dosyalarda
/// tutulur: Android'in SQLite imleç penceresi büyük satırlarda hata verebilir.
class SqfliteStore implements LocalStore {
  SqfliteStore._(this._db, this._cacheDir);

  final Database _db;
  final Directory _cacheDir;

  static const _dbName = 'techpulse.db';

  /// 1: kaydedilenler + önbellek. 2: favoriler ve okuma geçmişi eklendi.
  static const _version = 2;

  static Future<void> _createList(DatabaseExecutor db, String table) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        key TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        payload TEXT NOT NULL,
        saved_at INTEGER NOT NULL
      )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_${table}_saved ON $table (saved_at DESC)');
  }

  static Future<SqfliteStore> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, _dbName),
      version: _version,
      onCreate: (db, version) async {
        for (final list in UserList.values) {
          await _createList(db, list.name);
        }
        await db.execute('''
          CREATE TABLE cache_index (
            key TEXT PRIMARY KEY,
            saved_at INTEGER NOT NULL,
            bytes INTEGER NOT NULL
          )''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createList(db, UserList.favorites.name);
          await _createList(db, UserList.history.name);
        }
      },
    );
    final cacheDir = Directory(p.join(dir, 'feed_cache'));
    if (!cacheDir.existsSync()) await cacheDir.create(recursive: true);
    return SqfliteStore._(db, cacheDir);
  }

  File _file(String key) => File(p.join(_cacheDir.path, '${key.replaceAll(RegExp('[^a-z0-9_-]'), '_')}.json'));

  @override
  Future<CachedBody?> readCache(String key) async {
    final rows = await _db.query('cache_index', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    final file = _file(key);
    if (!file.existsSync()) return null;
    final savedAt = DateTime.fromMillisecondsSinceEpoch(rows.first['saved_at'] as int);
    return CachedBody(await file.readAsString(), savedAt);
  }

  @override
  Future<void> writeCache(String key, String body) async {
    // Önce geçici dosyaya yazıp sonra adını değiştiriyoruz: yazma yarıda kalırsa eski önbellek bozulmaz.
    final target = _file(key);
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(body, flush: true);
    await temp.rename(target.path);
    await _db.insert(
      'cache_index',
      {'key': key, 'saved_at': DateTime.now().millisecondsSinceEpoch, 'bytes': body.length},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clearCache() async {
    await _db.delete('cache_index');
    if (_cacheDir.existsSync()) {
      for (final entity in _cacheDir.listSync()) {
        if (entity is File) await entity.delete();
      }
    }
  }

  @override
  Future<List<BookmarkRecord>> records(UserList list) async {
    final rows = await _db.query(list.name, orderBy: 'saved_at DESC');
    final out = <BookmarkRecord>[];
    for (final row in rows) {
      final kind = BookmarkKind.values.where((k) => k.name == row['kind']).firstOrNull;
      if (kind == null) continue;
      out.add(
        BookmarkRecord(
          key: row['key'] as String,
          kind: kind,
          payload: row['payload'] as String,
          savedAt: DateTime.fromMillisecondsSinceEpoch(row['saved_at'] as int),
        ),
      );
    }
    return out;
  }

  @override
  Future<void> saveRecord(UserList list, BookmarkRecord record) async {
    await _db.insert(
      list.name,
      {
        'key': record.key,
        'kind': record.kind.name,
        'payload': record.payload,
        'saved_at': record.savedAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (list == UserList.history) {
      // Geçmiş sınırsız büyümesin: en yeni kayıtlar kalır.
      await _db.execute(
        'DELETE FROM history WHERE key NOT IN (SELECT key FROM history ORDER BY saved_at DESC LIMIT $historyLimit)',
      );
    }
  }

  @override
  Future<void> deleteRecord(UserList list, String key) async {
    await _db.delete(list.name, where: 'key = ?', whereArgs: [key]);
  }

  @override
  Future<void> clearList(UserList list) async {
    await _db.delete(list.name);
  }
}
