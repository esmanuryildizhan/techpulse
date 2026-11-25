import '../core/config.dart';
import 'data_source.dart';
import 'local_store.dart';

/// Veri hattının yayınladığı uç noktalar.
enum Endpoint {
  news('news.json'),
  models('models.json'),
  papers('papers.json'),
  repos('repos.json'),
  security('security.json'),
  meta('meta.json');

  const Endpoint(this.path);

  final String path;
}

/// Ekrana verilen veri: içerik, ne zaman kaydedildiği ve son ağ denemesinin sonucu.
class Snapshot<T> {
  const Snapshot(this.data, {required this.savedAt, required this.fromCache, this.error});

  final T data;
  final DateTime? savedAt;

  /// Veri telefondaki önbellekten mi geldi?
  final bool fromCache;

  /// Ağdan yenileme başarısız olduysa nedeni; veri yine de önbellekten gösterilir.
  final AppException? error;

  bool get isOffline => error?.offline ?? false;
}

/// "Önce önbellek, sonra ağ" (stale-while-revalidate) deposu.
///
/// 1. Önbellekte veri varsa hemen gösterilir.
/// 2. Önbellek çok yeniyse (2 dakika) ağa gidilmez.
/// 3. Ağdan yeni veri gelirse önce doğrulanır, sonra önbelleğe yazılıp gösterilir.
/// 4. Ağ hatasında önbellekteki veri, hata bilgisiyle birlikte gösterilmeye devam eder.
class TechPulseRepository {
  TechPulseRepository(this._source, this._store, {Duration? freshFor, DateTime Function()? clock})
      : _freshFor = freshFor ?? AppConfig.cacheFreshness,
        _clock = clock ?? DateTime.now;

  final DataSource _source;
  final LocalStore _store;
  final Duration _freshFor;
  final DateTime Function() _clock;

  Stream<Snapshot<T>> watch<T>(Endpoint endpoint, T Function(String body) parse) async* {
    final cached = await _readCache(endpoint);
    T? cachedData;
    if (cached != null) {
      try {
        cachedData = parse(cached.body);
      } catch (_) {
        cachedData = null; // bozuk önbellek: yok say, ağdan iste
      }
    }
    if (cached != null && cachedData != null) {
      yield Snapshot(cachedData, savedAt: cached.savedAt, fromCache: true);
      if (_clock().difference(cached.savedAt) < _freshFor) return;
    }

    try {
      final body = await _source.getText(endpoint.path);
      final fresh = parse(body); // önce doğrula: bozuk veri önbelleğe yazılmaz
      await _writeCache(endpoint, body);
      yield Snapshot(fresh, savedAt: _clock(), fromCache: false);
    } catch (error) {
      final appError = AppException.from(error);
      if (cached != null && cachedData != null) {
        yield Snapshot(cachedData, savedAt: cached.savedAt, fromCache: true, error: appError);
      } else {
        throw appError;
      }
    }
  }

  /// Kullanıcı aşağı çekip yenilediğinde çağrılır: ağdan indirir, doğrular, önbelleğe yazar.
  Future<void> refresh<T>(Endpoint endpoint, T Function(String body) parse) async {
    final body = await _source.getText(endpoint.path);
    parse(body);
    await _writeCache(endpoint, body);
  }

  Future<CachedBody?> _readCache(Endpoint endpoint) async {
    try {
      return await _store.readCache(endpoint.name);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(Endpoint endpoint, String body) async {
    try {
      await _store.writeCache(endpoint.name, body);
    } catch (_) {
      // Önbelleğe yazılamaması (ör. disk dolu) veriyi göstermeye engel değildir.
    }
  }
}
