import 'local_store_stub.dart' if (dart.library.io) 'local_store_sqflite.dart' as platform;

/// Önbellekteki bir uç noktanın gövdesi ve kaydedilme zamanı.
class CachedBody {
  const CachedBody(this.body, this.savedAt);

  final String body;
  final DateTime savedAt;
}

/// Telefonda saklanan bir içerik kaydı: kaydedilenler, favoriler ve okuma geçmişi aynı biçimi kullanır.
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

/// Kişisel listeler: her biri ayrı bir SQLite tablosudur.
enum UserList {
  /// Daha sonra okumak için kaydedilenler.
  bookmarks,

  /// Beğenilen (favori) içerikler.
  favorites,

  /// Okunan haberler; en yeni 300 kayıt tutulur.
  history,
}

/// Telefondaki kalıcı depolama. Android ve iOS'ta SQLite (sqflite), testlerde bellekte çalışır.
abstract interface class LocalStore {
  Future<CachedBody?> readCache(String key);
  Future<void> writeCache(String key, String body);
  Future<void> clearCache();
  Future<List<BookmarkRecord>> records(UserList list);
  Future<void> saveRecord(UserList list, BookmarkRecord record);
  Future<void> deleteRecord(UserList list, String key);
  Future<void> clearList(UserList list);
}

/// Okuma geçmişinde tutulan en fazla kayıt.
const int historyLimit = 300;

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
  final Map<UserList, Map<String, BookmarkRecord>> _lists = {for (final l in UserList.values) l: {}};

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
  Future<List<BookmarkRecord>> records(UserList list) async =>
      _lists[list]!.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));

  @override
  Future<void> saveRecord(UserList list, BookmarkRecord record) async {
    final map = _lists[list]!;
    map[record.key] = record;
    if (list == UserList.history && map.length > historyLimit) {
      final oldest = map.values.reduce((a, b) => a.savedAt.isBefore(b.savedAt) ? a : b);
      map.remove(oldest.key);
    }
  }

  @override
  Future<void> deleteRecord(UserList list, String key) async {
    _lists[list]!.remove(key);
  }

  @override
  Future<void> clearList(UserList list) async {
    _lists[list]!.clear();
  }
}
