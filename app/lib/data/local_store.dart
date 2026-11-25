import 'local_store_stub.dart' if (dart.library.io) 'local_store_sqflite.dart' as platform;

/// Önbellekteki bir uç noktanın gövdesi ve kaydedilme zamanı.
class CachedBody {
  const CachedBody(this.body, this.savedAt);

  final String body;
  final DateTime savedAt;
}

/// Kullanıcının kaydettiği bir içerik (haber, makale, model, proje veya güvenlik açığı).
class BookmarkRecord {
  const BookmarkRecord({required this.key, required this.kind, required this.payload, required this.savedAt});

  /// `tür:kimlik`, ör. `news:9f2c…`
  final String key;
  final BookmarkKind kind;

  /// Kaydın JSON metni; çevrimdışıyken de gösterilebilsin diye tamamı saklanır.
  final String payload;
  final DateTime savedAt;

  static String keyFor(BookmarkKind kind, String id) => '${kind.name}:$id';
}

enum BookmarkKind { news, paper, model, repo, vuln }

/// Telefondaki kalıcı depolama. Android ve iOS'ta SQLite (sqflite), testlerde bellekte çalışır.
abstract interface class LocalStore {
  Future<CachedBody?> readCache(String key);
  Future<void> writeCache(String key, String body);
  Future<void> clearCache();
  Future<List<BookmarkRecord>> bookmarks();
  Future<void> saveBookmark(BookmarkRecord record);
  Future<void> deleteBookmark(String key);
}

/// Platform deposunu açar; açılamazsa uygulama bellek deposuyla çalışmaya devam eder.
Future<LocalStore> openLocalStore() async {
  try {
    return await platform.openPlatformStore();
  } catch (_) {
    return MemoryStore();
  }
}

class MemoryStore implements LocalStore {
  final Map<String, CachedBody> _cache = {};
  final Map<String, BookmarkRecord> _bookmarks = {};

  @override
  Future<CachedBody?> readCache(String key) async => _cache[key];

  @override
  Future<void> writeCache(String key, String body) async {
    _cache[key] = CachedBody(body, DateTime.now());
  }

  @override
  Future<void> clearCache() async {
    _cache.clear();
  }

  @override
  Future<List<BookmarkRecord>> bookmarks() async =>
      _bookmarks.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));

  @override
  Future<void> saveBookmark(BookmarkRecord record) async {
    _bookmarks[record.key] = record;
  }

  @override
  Future<void> deleteBookmark(String key) async {
    _bookmarks.remove(key);
  }
}
