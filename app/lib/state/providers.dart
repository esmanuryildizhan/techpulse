import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/categories.dart';
import '../core/config.dart';
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

/// Aşağı çekip yenileme. Başarısız olursa kullanıcıya gösterilecek mesajı döndürür.
Future<String?> refreshFeed<T>(
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
    return AppException.from(error).message;
  }
}

/// Haber akışını ve kaynak durumunu birlikte yeniler.
Future<String?> refreshNews(WidgetRef ref) async {
  final message = await refreshFeed(ref, Endpoint.news, parseNews, () => ref.invalidate(newsProvider));
  unawaited(refreshFeed(ref, Endpoint.meta, parseMeta, () => ref.invalidate(metaProvider)));
  unawaited(refreshFeed(ref, Endpoint.security, parseSecurity, () => ref.invalidate(securityProvider)));
  return message;
}

// ---------------------------------------------------------------------------
// Ayarlar
// ---------------------------------------------------------------------------

@immutable
class AppSettings {
  const AppSettings({required this.themeMode, required this.showOriginalTitles});

  final ThemeMode themeMode;

  /// Türkçe başlığın altında kaynağın orijinal başlığını da göster.
  final bool showOriginalTitles;

  AppSettings copyWith({ThemeMode? themeMode, bool? showOriginalTitles}) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        showOriginalTitles: showOriginalTitles ?? this.showOriginalTitles,
      );
}

class SettingsController extends Notifier<AppSettings> {
  static const _themeKey = 'settings.themeMode';
  static const _originalKey = 'settings.showOriginalTitles';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final themeName = prefs.getString(_themeKey);
    return AppSettings(
      // Varsayılan tema koyu.
      themeMode: ThemeMode.values.where((m) => m.name == themeName).firstOrNull ?? ThemeMode.dark,
      showOriginalTitles: prefs.getBool(_originalKey) ?? false,
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    unawaited(ref.read(sharedPreferencesProvider).setString(_themeKey, mode.name));
  }

  void setShowOriginalTitles(bool value) {
    state = state.copyWith(showOriginalTitles: value);
    unawaited(ref.read(sharedPreferencesProvider).setBool(_originalKey, value));
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

// ---------------------------------------------------------------------------
// Profil (yalnızca bu cihazda saklanır; hesap gerekmez)
// ---------------------------------------------------------------------------

@immutable
class Profile {
  const Profile({
    required this.name,
    required this.colorIndex,
    required this.interests,
    required this.onboarded,
    required this.notifyInterests,
    required this.notifyImportant,
    required this.notifyThreats,
    required this.updatesSeenAt,
  });

  final String name;
  final int colorIndex;

  /// Kullanıcının seçtiği konular, önem sırasıyla. Ana sayfadaki konu sırası buna göre belirlenir.
  final List<TechCategory> interests;
  final bool onboarded;

  /// Uygulama içi bildirimler (zil simgesi): ilgi alanlarındaki yeni haberler, önemli gelişmeler, yeni tehditler.
  final bool notifyInterests;
  final bool notifyImportant;
  final bool notifyThreats;

  /// Kullanıcı "Yenilikler" ekranına en son ne zaman baktı.
  final DateTime? updatesSeenAt;

  String get displayName => name.trim().isEmpty ? 'TechPulse okuru' : name.trim();

  String get initials {
    final parts = displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'T';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts[1].characters.first : '';
    return trUpper('$first$second');
  }

  /// Konuların gösterim sırası: önce ilgi alanları (seçilme sırasıyla), sonra diğerleri.
  List<TechCategory> get categoryOrder => [
        ...interests,
        ...TechCategory.values.where((c) => !interests.contains(c)),
      ];

  Profile copyWith({
    String? name,
    int? colorIndex,
    List<TechCategory>? interests,
    bool? onboarded,
    bool? notifyInterests,
    bool? notifyImportant,
    bool? notifyThreats,
    DateTime? updatesSeenAt,
  }) =>
      Profile(
        name: name ?? this.name,
        colorIndex: colorIndex ?? this.colorIndex,
        interests: interests ?? this.interests,
        onboarded: onboarded ?? this.onboarded,
        notifyInterests: notifyInterests ?? this.notifyInterests,
        notifyImportant: notifyImportant ?? this.notifyImportant,
        notifyThreats: notifyThreats ?? this.notifyThreats,
        updatesSeenAt: updatesSeenAt ?? this.updatesSeenAt,
      );
}

class ProfileController extends Notifier<Profile> {
  static const _name = 'profile.name';
  static const _color = 'profile.color';
  static const _interests = 'profile.interests';
  static const _onboarded = 'profile.onboarded';
  static const _nInterests = 'profile.notify.interests';
  static const _nImportant = 'profile.notify.important';
  static const _nThreats = 'profile.notify.threats';
  static const _seen = 'profile.updatesSeenAt';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Profile build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final seen = prefs.getInt(_seen);
    return Profile(
      name: prefs.getString(_name) ?? '',
      colorIndex: prefs.getInt(_color) ?? 0,
      interests: [
        for (final key in prefs.getStringList(_interests) ?? const <String>[]) ?TechCategory.tryKey(key),
      ],
      onboarded: prefs.getBool(_onboarded) ?? false,
      notifyInterests: prefs.getBool(_nInterests) ?? true,
      notifyImportant: prefs.getBool(_nImportant) ?? true,
      notifyThreats: prefs.getBool(_nThreats) ?? true,
      updatesSeenAt: seen == null ? null : DateTime.fromMillisecondsSinceEpoch(seen),
    );
  }

  void setName(String name) {
    state = state.copyWith(name: name.trim());
    unawaited(_prefs.setString(_name, name.trim()));
  }

  void setColor(int index) {
    state = state.copyWith(colorIndex: index);
    unawaited(_prefs.setInt(_color, index));
  }

  void setInterests(List<TechCategory> interests) {
    state = state.copyWith(interests: List.unmodifiable(interests));
    unawaited(_prefs.setStringList(_interests, [for (final c in interests) c.key]));
  }

  void toggleInterest(TechCategory category) {
    final next = [...state.interests];
    if (!next.remove(category)) next.add(category);
    setInterests(next);
  }

  void completeOnboarding({required String name, required List<TechCategory> interests}) {
    setName(name);
    setInterests(interests);
    state = state.copyWith(onboarded: true, updatesSeenAt: ref.read(clockProvider)());
    unawaited(_prefs.setBool(_onboarded, true));
    unawaited(_prefs.setInt(_seen, state.updatesSeenAt!.millisecondsSinceEpoch));
  }

  void setNotify({bool? interests, bool? important, bool? threats}) {
    state = state.copyWith(notifyInterests: interests, notifyImportant: important, notifyThreats: threats);
    if (interests != null) unawaited(_prefs.setBool(_nInterests, interests));
    if (important != null) unawaited(_prefs.setBool(_nImportant, important));
    if (threats != null) unawaited(_prefs.setBool(_nThreats, threats));
  }

  void markUpdatesSeen() {
    final now = ref.read(clockProvider)();
    state = state.copyWith(updatesSeenAt: now);
    unawaited(_prefs.setInt(_seen, now.millisecondsSinceEpoch));
  }

  /// Profil bilgilerini ilk açılış durumuna döndürür (kişisel listeler ayrıca temizlenir).
  Future<void> reset() async {
    for (final key in [_name, _color, _interests, _onboarded, _nInterests, _nImportant, _nThreats, _seen]) {
      await _prefs.remove(key);
    }
    ref.invalidateSelf();
  }
}

final profileProvider = NotifierProvider<ProfileController, Profile>(ProfileController.new);

// ---------------------------------------------------------------------------
// Kişisel listeler: kaydedilenler, favoriler, okuma geçmişi (telefondaki SQLite veritabanında)
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
    final record = BookmarkRecord(key: key, kind: kind, payload: jsonEncode(entry.raw), savedAt: ref.read(clockProvider)());
    await _store.saveRecord(list, record);
    final next = [record, ...current.where((b) => b.key != key)];
    state = AsyncData(list == UserList.history ? next.take(historyLimit).toList() : next);
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
final favoritesProvider = AsyncNotifierProvider<UserListController, List<BookmarkRecord>>(
  () => UserListController(UserList.favorites),
);
final historyProvider = AsyncNotifierProvider<UserListController, List<BookmarkRecord>>(
  () => UserListController(UserList.history),
);

final isBookmarkedProvider = Provider.family<bool, String>(
  (ref, key) => ref.watch(bookmarksProvider).value?.any((b) => b.key == key) ?? false,
);
final isFavoriteProvider = Provider.family<bool, String>(
  (ref, key) => ref.watch(favoritesProvider).value?.any((b) => b.key == key) ?? false,
);
final isReadProvider = Provider.family<bool, String>(
  (ref, key) => ref.watch(historyProvider).value?.any((b) => b.key == key) ?? false,
);

// ---------------------------------------------------------------------------
// Gezinme
// ---------------------------------------------------------------------------

/// Alt gezinme çubuğundaki sekmeler.
enum AppTab { home, discover, saved, profile }

class AppTabController extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void select(AppTab tab) => state = tab;
}

final appTabProvider = NotifierProvider<AppTabController, AppTab>(AppTabController.new);
