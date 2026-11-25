import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// ---------------------------------------------------------------------------
// Ayarlar
// ---------------------------------------------------------------------------

@immutable
class AppSettings {
  const AppSettings({required this.themeMode, required this.showOriginalTitles});

  final ThemeMode themeMode;

  /// Türkçe başlığın altında İngilizce orijinal başlığı da göster.
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
      themeMode: ThemeMode.values.where((m) => m.name == themeName).firstOrNull ?? ThemeMode.system,
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
// Kaydedilenler
// ---------------------------------------------------------------------------

class BookmarksController extends AsyncNotifier<List<BookmarkRecord>> {
  @override
  Future<List<BookmarkRecord>> build() => ref.watch(localStoreProvider).bookmarks();

  LocalStore get _store => ref.read(localStoreProvider);

  /// Kayıtlıysa çıkarır, değilse kaydeder. Yeni durumu (kayıtlı mı) döndürür.
  Future<bool> toggle(BookmarkKind kind, Entry entry) async {
    final key = BookmarkRecord.keyFor(kind, entry.id);
    final current = state.value ?? await future;
    if (current.any((b) => b.key == key)) {
      await _store.deleteBookmark(key);
      state = AsyncData(current.where((b) => b.key != key).toList());
      return false;
    }
    final record = BookmarkRecord(key: key, kind: kind, payload: jsonEncode(entry.raw), savedAt: DateTime.now());
    await _store.saveBookmark(record);
    state = AsyncData([record, ...current]);
    return true;
  }

  Future<void> remove(BookmarkRecord record) async {
    final current = state.value ?? await future;
    await _store.deleteBookmark(record.key);
    state = AsyncData(current.where((b) => b.key != record.key).toList());
  }

  Future<void> restore(BookmarkRecord record) async {
    final current = state.value ?? await future;
    await _store.saveBookmark(record);
    final next = [record, ...current.where((b) => b.key != record.key)]
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    state = AsyncData(next);
  }
}

final bookmarksProvider = AsyncNotifierProvider<BookmarksController, List<BookmarkRecord>>(BookmarksController.new);

final isBookmarkedProvider = Provider.family<bool, String>(
  (ref, key) => ref.watch(bookmarksProvider).value?.any((b) => b.key == key) ?? false,
);
