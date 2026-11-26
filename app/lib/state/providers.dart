import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/categories.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../data/data_source.dart';
import '../data/local_store.dart';
import '../data/models.dart';
import '../data/repository.dart';

// ---------------------------------------------------------------------------
// Altyapı. main.dart gerçek nesneleri, testler sahtelerini verir (override).
// ---------------------------------------------------------------------------

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('main.dart içinde override edilmeli'),
);

final localStoreProvider = Provider<LocalStore>((ref) => MemoryStore());

final dataSourceProvider = Provider<DataSource>((ref) => HttpDataSource(baseUrl: AppConfig.apiBaseUrl));

final repositoryProvider = Provider<TechPulseRepository>(
  (ref) => TechPulseRepository(ref.watch(dataSourceProvider), ref.watch(localStoreProvider)),
);

/// Testlerde sabit bir "şimdi" vermek için.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

// ---------------------------------------------------------------------------
// Veri akışları: her biri önce önbelleği, sonra ağdan geleni yayar.
// ---------------------------------------------------------------------------

Feed<NewsItem> parseNews(String body) => Feed.parse(body, NewsItem.fromJson);
Feed<AiModel> parseModels(String body) => Feed.parse(body, AiModel.fromJson);
Feed<Paper> parsePapers(String body) => Feed.parse(body, Paper.fromJson);
Feed<Repo> parseRepos(String body) => Feed.parse(body, Repo.fromJson);
Feed<Vulnerability> parseSecurity(String body) => Feed.parse(body, Vulnerability.fromJson);

final newsProvider = StreamProvider<Snapshot<Feed<NewsItem>>>(
  (ref) => ref.watch(repositoryProvider).watch(Endpoint.news, parseNews),
);

final modelsProvider = StreamProvider<Snapshot<Feed<AiModel>>>(
  (ref) => ref.watch(repositoryProvider).watch(Endpoint.models, parseModels),
);

final papersProvider = StreamProvider<Snapshot<Feed<Paper>>>(
  (ref) => ref.watch(repositoryProvider).watch(Endpoint.papers, parsePapers),
);

final reposProvider = StreamProvider<Snapshot<Feed<Repo>>>(
  (ref) => ref.watch(repositoryProvider).watch(Endpoint.repos, parseRepos),
);

final securityProvider = StreamProvider<Snapshot<Feed<Vulnerability>>>(
  (ref) => ref.watch(repositoryProvider).watch(Endpoint.security, parseSecurity),
);

final metaProvider = StreamProvider<Snapshot<FeedMeta>>(
  (ref) => ref.watch(repositoryProvider).watch(Endpoint.meta, parseMeta),
);

/// Uygulamada gösterilecek haberler (editörün gizlediği ilgisiz kayıtlar hariç), en yeniden eskiye.
final visibleNewsProvider = Provider<List<NewsItem>>((ref) {
  final items = ref.watch(newsProvider).value?.data.items ?? const <NewsItem>[];
  return items.where((n) => !n.hidden).toList()..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
});

/// Aşağı çekip yenileme. Başarısız olursa kullanıcıya gösterilecek hatayı döndürür.
Future<AppException?> refreshFeed<T>(
  WidgetRef ref,
  Endpoint endpoint,
  T Function(String body) parse,
  void Function() invalidate,
) async {
  try {
    await ref.read(repositoryProvider).refresh(endpoint, parse);
    invalidate();
    return null;
  } catch (error) {
    return AppException.from(error);
  }
}

/// Haber akışını ve kaynak durumunu birlikte yeniler.
Future<AppException?> refreshNews(WidgetRef ref) async {
  final error = await refreshFeed(ref, Endpoint.news, parseNews, () => ref.invalidate(newsProvider));
  unawaited(refreshFeed(ref, Endpoint.meta, parseMeta, () => ref.invalidate(metaProvider)));
  unawaited(refreshFeed(ref, Endpoint.security, parseSecurity, () => ref.invalidate(securityProvider)));
  return error;
}

// ---------------------------------------------------------------------------
// Ayarlar (telefonda saklanır)
// ---------------------------------------------------------------------------

/// Haber metninin yazı boyutu.
enum ReadingSize {
  small('Küçük', 0.9),
  normal('Normal', 1.0),
  large('Büyük', 1.15),
  xlarge('Çok büyük', 1.3);

  const ReadingSize(this.label, this.scale);

  final String label;
  final double scale;

  ReadingSize get smaller => index == 0 ? this : ReadingSize.values[index - 1];
  ReadingSize get larger => index == ReadingSize.values.length - 1 ? this : ReadingSize.values[index + 1];
}

/// Haber anlatımının seviyesi.
enum ReadingLevel {
  simple('Sade anlatım', 'Konuyu bilmeyen biri için, günlük dille'),
  technical('Teknik derinlik', 'Sürümler, mimari ve teknik ayrıntılarla');

  const ReadingLevel(this.label, this.description);

  final String label;
  final String description;
}

@immutable
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.accent,
    required this.readingSize,
    required this.readingLevel,
    required this.showOriginalTitles,
    required this.recordHistory,
  });

  final ThemeMode themeMode;

  /// Uygulamanın vurgu rengi (düğmeler, seçili sekme, logo).
  final AccentColor accent;
  final ReadingSize readingSize;

  /// Haber açıldığında önce hangi anlatım gösterilsin.
  final ReadingLevel readingLevel;

  /// Türkçe başlığın altında kaynağın orijinal başlığını da göster.
  final bool showOriginalTitles;

  /// Okunan haberler okuma geçmişine kaydedilsin mi?
  final bool recordHistory;

  AppSettings copyWith({
    ThemeMode? themeMode,
    AccentColor? accent,
    ReadingSize? readingSize,
    ReadingLevel? readingLevel,
    bool? showOriginalTitles,
    bool? recordHistory,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    accent: accent ?? this.accent,
    readingSize: readingSize ?? this.readingSize,
    readingLevel: readingLevel ?? this.readingLevel,
    showOriginalTitles: showOriginalTitles ?? this.showOriginalTitles,
    recordHistory: recordHistory ?? this.recordHistory,
  );
}

class SettingsController extends Notifier<AppSettings> {
  static const _theme = 'settings.themeMode';
  static const _accent = 'settings.accent';
  static const _size = 'settings.readingSize';
  static const _level = 'settings.readingLevel';
  static const _original = 'settings.showOriginalTitles';
  static const _history = 'settings.recordHistory';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    T pick<T extends Enum>(List<T> values, String key, T fallback) =>
        values.where((v) => v.name == prefs.getString(key)).firstOrNull ?? fallback;
    return AppSettings(
      // Varsayılan: telefonun açık/koyu tema ayarı.
      themeMode: pick(ThemeMode.values, _theme, ThemeMode.system),
      accent: AccentColor.fromName(prefs.getString(_accent)),
      readingSize: pick(ReadingSize.values, _size, ReadingSize.normal),
      readingLevel: pick(ReadingLevel.values, _level, ReadingLevel.simple),
      showOriginalTitles: prefs.getBool(_original) ?? false,
      recordHistory: prefs.getBool(_history) ?? true,
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    unawaited(_prefs.setString(_theme, mode.name));
  }

  void setAccent(AccentColor accent) {
    state = state.copyWith(accent: accent);
    unawaited(_prefs.setString(_accent, accent.name));
  }

  void setReadingSize(ReadingSize size) {
    state = state.copyWith(readingSize: size);
    unawaited(_prefs.setString(_size, size.name));
  }

  void setReadingLevel(ReadingLevel level) {
    state = state.copyWith(readingLevel: level);
    unawaited(_prefs.setString(_level, level.name));
  }

  void setShowOriginalTitles(bool value) {
    state = state.copyWith(showOriginalTitles: value);
    unawaited(_prefs.setBool(_original, value));
  }

  void setRecordHistory(bool value) {
    state = state.copyWith(recordHistory: value);
    unawaited(_prefs.setBool(_history, value));
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

// ---------------------------------------------------------------------------
// Profil (yalnızca bu telefonda saklanır; hesap gerekmez)
// ---------------------------------------------------------------------------

@immutable
class Profile {
  const Profile({required this.name, required this.interests, required this.onboarded});

  /// Ana sayfadaki selamda kullanılır ("Günaydın, Esma").
  final String name;

  /// Kullanıcının seçtiği konular. "Sizin İçin" akışı bu konulardan oluşur.
  final List<TechCategory> interests;
  final bool onboarded;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get displayName => name.trim().isEmpty ? 'TechPulse okuru' : name.trim();

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts[1].characters.first : '';
    return trUpper('$first$second');
  }

  Profile copyWith({String? name, List<TechCategory>? interests, bool? onboarded}) =>
      Profile(name: name ?? this.name, interests: interests ?? this.interests, onboarded: onboarded ?? this.onboarded);
}

class ProfileController extends Notifier<Profile> {
  static const _name = 'profile.name';
  static const _interests = 'profile.interests';
  static const _onboarded = 'profile.onboarded';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Profile build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return Profile(
      name: prefs.getString(_name) ?? '',
      interests: [for (final key in prefs.getStringList(_interests) ?? const <String>[]) ?TechCategory.tryKey(key)],
      onboarded: prefs.getBool(_onboarded) ?? false,
    );
  }

  void setName(String name) {
    state = state.copyWith(name: name.trim());
    unawaited(_prefs.setString(_name, name.trim()));
  }

  void setInterests(List<TechCategory> interests) {
    state = state.copyWith(interests: List.unmodifiable(interests));
    unawaited(_prefs.setStringList(_interests, [for (final c in interests) c.key]));
  }

  void completeOnboarding({required String name, required List<TechCategory> interests}) {
    setName(name);
    setInterests(interests);
    state = state.copyWith(onboarded: true);
    unawaited(_prefs.setBool(_onboarded, true));
  }
}

final profileProvider = NotifierProvider<ProfileController, Profile>(ProfileController.new);

/// Bu telefondaki bütün kişisel verileri siler: profil, ayarlar, kaydedilenler, okuma geçmişi ve önbellek.
/// Uygulama ilk açılış ekranına döner.
Future<void> resetAllUserData(WidgetRef ref) async {
  await ref.read(localStoreProvider).clearAll();
  await ref.read(sharedPreferencesProvider).clear();
  ref.invalidate(bookmarksProvider);
  ref.invalidate(historyProvider);
  ref.invalidate(settingsProvider);
  ref.invalidate(profileProvider);
  ref.invalidate(homeFeedProvider);
  ref.invalidate(appTabProvider);
}

// ---------------------------------------------------------------------------
// Kişisel listeler: kaydedilenler ve okuma geçmişi (telefondaki SQLite veritabanında)
// ---------------------------------------------------------------------------

class UserListController extends AsyncNotifier<List<BookmarkRecord>> {
  UserListController(this.list);

  final UserList list;

  @override
  Future<List<BookmarkRecord>> build() => ref.watch(localStoreProvider).records(list);

  LocalStore get _store => ref.read(localStoreProvider);

  bool contains(String key) => state.value?.any((b) => b.key == key) ?? false;

  /// Listede varsa çıkarır, yoksa ekler. Yeni durumu (listede mi) döndürür.
  Future<bool> toggle(BookmarkKind kind, Entry entry) async {
    final key = BookmarkRecord.keyFor(kind, entry.id);
    final current = state.value ?? await future;
    if (current.any((b) => b.key == key)) {
      await _store.deleteRecord(list, key);
      state = AsyncData(current.where((b) => b.key != key).toList());
      return false;
    }
    await add(kind, entry);
    return true;
  }

  /// Ekler veya (geçmişte) zamanını günceller.
  Future<void> add(BookmarkKind kind, Entry entry) async {
    final key = BookmarkRecord.keyFor(kind, entry.id);
    final current = state.value ?? await future;
    final record = BookmarkRecord(
      key: key,
      kind: kind,
      payload: jsonEncode(entry.raw),
      savedAt: ref.read(clockProvider)(),
    );
    await _store.saveRecord(list, record);
    if (list == UserList.history) {
      // Depo, saklama süresini ve sınırı uygular; liste depodan yeniden okunur.
      state = AsyncData(await _store.records(list));
    } else {
      state = AsyncData([record, ...current.where((b) => b.key != key)]);
    }
  }

  Future<void> remove(BookmarkRecord record) async {
    final current = state.value ?? await future;
    await _store.deleteRecord(list, record.key);
    state = AsyncData(current.where((b) => b.key != record.key).toList());
  }

  Future<void> restore(BookmarkRecord record) async {
    final current = state.value ?? await future;
    await _store.saveRecord(list, record);
    final next = [record, ...current.where((b) => b.key != record.key)]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    state = AsyncData(next);
  }

  Future<void> clear() async {
    await _store.clearList(list);
    state = const AsyncData([]);
  }
}

final bookmarksProvider = AsyncNotifierProvider<UserListController, List<BookmarkRecord>>(
  () => UserListController(UserList.bookmarks),
);
final historyProvider = AsyncNotifierProvider<UserListController, List<BookmarkRecord>>(
  () => UserListController(UserList.history),
);

final isBookmarkedProvider = Provider.family<bool, String>(
  (ref, key) => ref.watch(bookmarksProvider).value?.any((b) => b.key == key) ?? false,
);
final isReadProvider = Provider.family<bool, String>(
  (ref, key) => ref.watch(historyProvider).value?.any((b) => b.key == key) ?? false,
);

/// Okuma geçmişindeki son 40 haberin konu dağılımı (0-1). "Sizin İçin" sıralamasında hafif bir etki yapar.
final readingAffinityProvider = Provider<Map<TechCategory, double>>((ref) {
  final records = ref.watch(historyProvider).value ?? const <BookmarkRecord>[];
  final counts = <TechCategory, int>{};
  var total = 0;
  for (final record in records.where((r) => r.kind == BookmarkKind.news).take(40)) {
    try {
      final json = jsonDecode(record.payload);
      if (json is! Map<String, dynamic>) continue;
      final category = TechCategory.fromKey(json['category']);
      counts[category] = (counts[category] ?? 0) + 1;
      total++;
    } catch (_) {
      continue;
    }
  }
  if (total == 0) return const {};
  return {for (final e in counts.entries) e.key: e.value / total};
});

// ---------------------------------------------------------------------------
// Ana sayfa akışı: görünüm (Sizin İçin / Tüm Gündem) ve filtreler (konu, zaman, sıralama)
// ---------------------------------------------------------------------------

enum FeedMode { forYou, all }

enum TimeRange {
  any('Tüm zamanlar', null),
  hour('Son 1 saat', Duration(hours: 1)),
  day('Son 24 saat', Duration(hours: 24)),
  week('Son 7 gün', Duration(days: 7)),
  month('Son 30 gün', Duration(days: 30));

  const TimeRange(this.label, this.duration);

  final String label;
  final Duration? duration;
}

enum FeedSort {
  recommended('Önerilen'),
  newest('En yeni'),
  oldest('En eski');

  const FeedSort(this.label);

  final String label;
}

@immutable
class FeedFilter {
  const FeedFilter({this.categories = const {}, this.range = TimeRange.any, this.sort = FeedSort.recommended});

  final Set<TechCategory> categories;
  final TimeRange range;
  final FeedSort sort;

  bool get isActive => categories.isNotEmpty || range != TimeRange.any || sort != FeedSort.recommended;

  FeedFilter copyWith({Set<TechCategory>? categories, TimeRange? range, FeedSort? sort}) =>
      FeedFilter(categories: categories ?? this.categories, range: range ?? this.range, sort: sort ?? this.sort);
}

@immutable
class HomeFeedState {
  const HomeFeedState({this.mode = FeedMode.forYou, this.filter = const FeedFilter()});

  final FeedMode mode;
  final FeedFilter filter;
}

class HomeFeedController extends Notifier<HomeFeedState> {
  @override
  HomeFeedState build() => const HomeFeedState();

  void setMode(FeedMode mode) => state = HomeFeedState(mode: mode, filter: state.filter);

  void setFilter(FeedFilter filter) => state = HomeFeedState(mode: state.mode, filter: filter);

  void clearFilter() => state = HomeFeedState(mode: state.mode);
}

final homeFeedProvider = NotifierProvider<HomeFeedController, HomeFeedState>(HomeFeedController.new);

// ---------------------------------------------------------------------------
// Gezinme
// ---------------------------------------------------------------------------

/// Alt gezinme çubuğundaki sekmeler.
enum AppTab { home, discover, radar, saved, profile }

class AppTabController extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void select(AppTab tab) {
    if (tab == state) {
      // Açık sekmeye yeniden dokunulursa sayfa en başa kayar.
      ref.read(scrollToTopProvider.notifier).request(tab);
    }
    state = tab;
  }
}

final appTabProvider = NotifierProvider<AppTabController, AppTab>(AppTabController.new);

/// Radar sekmesinin bölümleri.
enum RadarSection {
  models('Modeller'),
  papers('Makaleler'),
  repos('Projeler'),
  threats('Tehditler');

  const RadarSection(this.label);

  final String label;
}

/// Radar'da açık bölüm. Başka bir ekrandan (ör. ana sayfadaki "Siber tehdit" kartı) belirli bir bölüm açılabilir.
class RadarSectionController extends Notifier<RadarSection> {
  @override
  RadarSection build() => RadarSection.models;

  void select(RadarSection section) => state = section;
}

final radarSectionProvider = NotifierProvider<RadarSectionController, RadarSection>(RadarSectionController.new);

/// Radar sekmesini belirli bir bölümle açar.
void openRadar(WidgetRef ref, RadarSection section) {
  ref.read(radarSectionProvider.notifier).select(section);
  ref.read(appTabProvider.notifier).select(AppTab.radar);
}

/// "Başa dön" isteği: hangi sekme ve kaçıncı istek.
class ScrollToTopController extends Notifier<({AppTab tab, int tick})> {
  @override
  ({AppTab tab, int tick}) build() => (tab: AppTab.home, tick: 0);

  void request(AppTab tab) => state = (tab: tab, tick: state.tick + 1);
}

final scrollToTopProvider = NotifierProvider<ScrollToTopController, ({AppTab tab, int tick})>(
  ScrollToTopController.new,
);
