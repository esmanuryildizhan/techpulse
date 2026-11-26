import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techpulse/core/categories.dart';
import 'package:techpulse/core/formatting.dart';
import 'package:techpulse/core/theme.dart';
import 'package:techpulse/data/data_source.dart';
import 'package:techpulse/data/local_store.dart';
import 'package:techpulse/data/models.dart';
import 'package:techpulse/data/repository.dart';
import 'package:techpulse/state/providers.dart';
import 'package:techpulse/state/ranking.dart';
import 'package:techpulse/ui/news/story_view.dart';

import 'helpers.dart';

void main() {
  setUpAll(initTestLocale);

  group('Ayrıştırma', () {
    final items = parseNews(fixture('news.json')).items;

    test('editörün v2 anlatımı tüm alanlarıyla okunur', () {
      final item = items.firstWhere((n) => n.story?.technical != null);
      final story = item.story!;
      expect(item.aiWritten, isTrue);
      expect(story.tldr, hasLength(3));
      expect(story.why, isNotEmpty);
      expect(story.simple.intro, isNotEmpty);
      expect(story.simple.sections, isNotEmpty);
      expect(story.simple.sections.first.paragraphs, isNotEmpty);
      expect(story.technical!.wordCount, greaterThan(100));
      expect(story.glossary, isNotEmpty);
      expect(story.glossary.first.definition, isNotEmpty);
      expect(story.fromExcerpt, isFalse);
      expect(items.where((n) => n.story?.fromExcerpt ?? false), isNotEmpty);
    });

    test('önceki biçimde (article) yazılmış haber de anlatım olarak gösterilir', () {
      final old = items.firstWhere((n) => n.raw['story'] == null && n.raw['article'] != null);
      expect(old.story, isNotNull);
      expect(old.story!.tldr, isEmpty);
      expect(old.story!.technical, isNull);
      expect(old.story!.simple.sections, isNotEmpty);
    });

    test('makine çevirisinde anlatım yoktur, gizli kayıt işaretlenir', () {
      final mt = items.firstWhere((n) => !n.aiWritten);
      expect(mt.story, isNull);
      expect(items.where((n) => n.hidden), hasLength(1));
    });

    test('Hacker News puanı kaynağıyla birlikte yazılır', () {
      final item = items.firstWhere((n) => n.points != null);
      expect(item.communityLabel, startsWith("Hacker News'te ${item.points} puan"));
      expect(item.discussionUrl, startsWith('https://news.ycombinator.com/'));
    });

    test('önceki sürümün konu kimliği ve eksik alanlar tolere edilir', () {
      final feed = parseNews(
        jsonEncode({
          'items': [
            {
              'id': 'old',
              'url': 'https://example.com/a',
              'sourceId': 'github-blog',
              'sourceName': 'GitHub Blog',
              'sourceKind': 'official',
              'publishedAt': '2026-11-20T10:00:00Z',
              'titleOriginal': 'Old record',
              'category': 'software',
            },
            {
              'id': 'insecure',
              'url': 'http://example.com/b',
              'sourceId': 'x',
              'sourceName': 'X',
              'publishedAt': '2026-11-20T10:00:00Z',
              'titleOriginal': 'T',
            },
          ],
        }),
      );
      final item = feed.items.single;
      expect(item.category, TechCategory.dev);
      expect(item.story, isNull);
      expect(item.topics, isEmpty);
      expect(item.imageUrl, isNull);
      expect(item.hidden, isFalse);
      expect(item.domain, 'example.com');
    });

    test('modeller, makaleler, projeler ve güvenlik kayıtları okunur', () {
      final models = parseModels(fixture('models.json')).items;
      expect(models.first.highlights, isA<List<String>>());
      final papers = parsePapers(fixture('papers.json')).items;
      expect(papers.first.story, isNotNull);
      final repos = parseRepos(fixture('repos.json')).items;
      final withStory = repos.where((r) => r.story != null).toList();
      expect(withStory, hasLength(2));
      expect(withStory.first.story!.useCases, isNotEmpty);
      expect(withStory.first.story!.caution, isNotEmpty);
      expect(withStory.first.story!.fromReadme, isTrue);
      final vulns = parseSecurity(fixture('security.json')).items;
      expect(vulns.first.explanationTr, isNotNull);
      final meta = parseMeta(fixture('meta.json'));
      expect(meta.sources.length, greaterThan(30));
    });

    test('bozuk zarf hata fırlatır, bozuk tek kayıt atlanır', () {
      expect(() => parseNews('[]'), throwsFormatException);
      expect(() => parseNews('{"items": 3}'), throwsFormatException);
      expect(parseNews('{"items":[{"id":"x"}, 5, null]}').items, isEmpty);
    });
  });

  group('Konular ve biçimlendirme', () {
    test('konu kimlikleri ve Türkçe büyük harf', () {
      expect(TechCategory.fromKey('security'), TechCategory.security);
      expect(TechCategory.fromKey('bilinmeyen'), TechCategory.industry);
      expect(TechCategory.tryKey('yok'), isNull);
      expect(trUpper('Siber güvenlik'), 'SİBER GÜVENLİK');
      expect(TechCategory.hardware.shortLabel, 'Donanım ve Çip');
    });

    test('Türkçe karakterlere duyarsız arama', () {
      expect(foldForSearch('Güvenlik İSTANBUL Işık'), 'guvenlik istanbul isik');
      expect(foldForSearch('ÇÖĞÜŞ'), 'cogus');
    });

    test('göreli zaman, selam ve kısa sayılar', () {
      final now = DateTime(2026, 11, 25, 12);
      expect(Fmt.relative(now.subtract(const Duration(seconds: 20)), now: now), 'az önce');
      expect(Fmt.relative(now.subtract(const Duration(minutes: 5)), now: now), '5 dk önce');
      expect(Fmt.relative(now.subtract(const Duration(hours: 3)), now: now), '3 sa önce');
      expect(Fmt.relative(now.subtract(const Duration(days: 1)), now: now), 'dün');
      expect(Fmt.greeting(DateTime(2026, 11, 25, 8)), 'Günaydın');
      expect(Fmt.greeting(DateTime(2026, 11, 25, 14)), 'İyi günler');
      expect(Fmt.greeting(DateTime(2026, 11, 25, 20)), 'İyi akşamlar');
      expect(Fmt.greeting(DateTime(2026, 11, 25, 2)), 'İyi geceler');
      expect(Fmt.compact(950), '950');
      expect(Fmt.compact(1200), contains('1,2'));
      expect(Fmt.prettyUrl('https://www.example.com/a/b?x=1'), 'example.com/a/b');
    });

    test('her vurgu renginde metin ve düğme yazısı okunur kalır', () {
      for (final accent in AccentColor.values) {
        for (final brightness in Brightness.values) {
          final c = TpColors.of(brightness, accent);
          final textContrast = _contrast(c.text, c.bg);
          final buttonContrast = _contrast(c.onAccent, c.accent);
          expect(textContrast, greaterThan(10), reason: '$accent $brightness metin');
          expect(buttonContrast, greaterThan(3), reason: '$accent $brightness düğme');
        }
      }
    });
  });

  group('Akış', () {
    final all = parseNews(fixture('news.json')).items.where((n) => !n.hidden).toList();

    test('manşet görselli olur; manşet, Kısaca ve Son gelişmeler tekrar etmez', () {
      final ranked = feedItems(all, testNow, mode: FeedMode.all, filter: const FeedFilter());
      final layout = HomeLayout.build(ranked, testNow);
      expect(layout.headline, isNotNull);
      expect(layout.headline!.imageUrl, isNotNull);
      expect(layout.briefs, hasLength(5));
      final ids = [layout.headline!.id, ...layout.briefs.map((n) => n.id), ...layout.latest.map((n) => n.id)];
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, hasLength(all.length));
      for (var i = 1; i < layout.latest.length; i++) {
        expect(layout.latest[i - 1].publishedAt.isBefore(layout.latest[i].publishedAt), isFalse);
      }
    });

    test('Sizin İçin yalnızca ilgi alanlarını gösterir; Tüm Gündem hepsini', () {
      const interests = [TechCategory.security, TechCategory.ai];
      final forYou = feedItems(all, testNow, mode: FeedMode.forYou, filter: const FeedFilter(), interests: interests);
      expect(forYou, isNotEmpty);
      expect(forYou.every((n) => interests.contains(n.category)), isTrue);
      final everything = feedItems(all, testNow, mode: FeedMode.all, filter: const FeedFilter(), interests: interests);
      expect(everything, hasLength(all.length));
      // İlgi alanı seçilmemişse Sizin İçin de bütün haberleri gösterir.
      expect(feedItems(all, testNow, mode: FeedMode.forYou, filter: const FeedFilter()), hasLength(all.length));
    });

    test('filtrede seçilen konu, görünümün konularının yerine geçer', () {
      final dev = feedItems(
        all,
        testNow,
        mode: FeedMode.forYou,
        filter: const FeedFilter(categories: {TechCategory.dev}),
        interests: const [TechCategory.security],
      );
      expect(dev, isNotEmpty);
      expect(dev.every((n) => n.category == TechCategory.dev), isTrue);
    });

    test('zaman aralığı ve sıralama uygulanır', () {
      final hour = feedItems(
        all,
        testNow,
        mode: FeedMode.all,
        filter: const FeedFilter(range: TimeRange.hour),
      );
      expect(hour.every((n) => testNow.difference(n.publishedAt) <= const Duration(hours: 1)), isTrue);
      final day = feedItems(
        all,
        testNow,
        mode: FeedMode.all,
        filter: const FeedFilter(range: TimeRange.day),
      );
      expect(day.length, greaterThan(hour.length));
      final newest = feedItems(
        all,
        testNow,
        mode: FeedMode.all,
        filter: const FeedFilter(sort: FeedSort.newest),
      );
      final oldest = feedItems(
        all,
        testNow,
        mode: FeedMode.all,
        filter: const FeedFilter(sort: FeedSort.oldest),
      );
      expect(newest.first.publishedAt.isAfter(newest.last.publishedAt), isTrue);
      expect(oldest.first.id, newest.last.id);
      expect(const FeedFilter().isActive, isFalse);
      expect(const FeedFilter(sort: FeedSort.oldest).isActive, isTrue);
    });

    test('ilgi alanındaki ve yeni haber önde gelir', () {
      final base = all.first;
      NewsItem copy({required int importance, required Duration age}) => NewsItem.fromJson({
        ...base.raw,
        'id': 'x$importance${age.inHours}',
        'importance': importance,
        'publishedAt': testNow.subtract(age).toIso8601String(),
      });
      final strong = copy(importance: 5, age: const Duration(hours: 2));
      final weak = copy(importance: 2, age: const Duration(hours: 2));
      final old = copy(importance: 5, age: const Duration(days: 5));
      expect(newsScore(strong, testNow), greaterThan(newsScore(weak, testNow)));
      expect(newsScore(strong, testNow), greaterThan(newsScore(old, testNow)));
      expect(newsScore(weak, testNow, interests: {base.category}), greaterThan(newsScore(weak, testNow)));
    });

    test('zaman başlıkları', () {
      final now = DateTime(2026, 11, 26, 12);
      expect(timeGroup(now.subtract(const Duration(minutes: 30)), now), 'Son 1 saat');
      expect(timeGroup(DateTime(2026, 11, 26, 9), now), 'Bugün');
      expect(timeGroup(DateTime(2026, 11, 25, 23), now), 'Dün');
      expect(timeGroup(DateTime(2026, 11, 22, 10), now), 'Bu hafta');
      expect(timeGroup(DateTime(2026, 11, 1), now), 'Daha önce');
    });

    test('popüler haberler ve trend konular', () {
      final popular = popularNews(all, testNow);
      expect(popular, hasLength(5));
      final topics = trendingTopics(all, testNow);
      expect(topics, isNotEmpty);
      expect(topics.first.count, greaterThan(0));
      expect(newsWithTopic(all, topics.first.label), isNotEmpty);
    });
  });

  group('Kavram işaretleme', () {
    test('Türkçe eklerle eşleşir, kısa kısaltma kelime içinde eşleşmez', () {
      expect(findTerm(foldSameLength("Clojure'un yeni çekirdeği"), foldSameLength('Clojure')), 0);
      expect(findTerm(foldSameLength('NuGet paketlerinde'), foldSameLength('NuGet')), 0);
      expect(findTerm(foldSameLength('MAIL sunucusu'), foldSameLength('AI')), -1);
      expect(findTerm(foldSameLength('Yeni AI modeli'), foldSameLength('AI')), 5);
      expect(findTerm(foldSameLength('Biri İSTANBUL'), foldSameLength('istanbul')), 5);
    });

    test('küçük harfe çevirme uzunluğu korur', () {
      const text = 'İzmir IŞIK Çağrı';
      expect(foldSameLength(text).length, text.length);
    });

    test('her kavramın yalnızca ilk geçtiği paragraf işaretlenir', () {
      const glossary = [GlossaryEntry(term: 'Rust', definition: 'Bir programlama dili.')];
      final plan = planGlossary(['Giriş metni.', 'Rust ile yazıldı.', 'Rust yine geçiyor.'], glossary);
      expect(plan[0], isEmpty);
      expect(plan[1].single.term, 'Rust');
      expect(plan[2], isEmpty);
    });
  });

  group('Ayarlar ve profil', () {
    test('varsayılanlar: tema sistemden, sade anlatım, geçmiş açık', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);
      final settings = container.read(settingsProvider);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.accent, AccentColor.orange);
      expect(settings.readingLevel, ReadingLevel.simple);
      expect(settings.readingSize, ReadingSize.normal);
      expect(settings.recordHistory, isTrue);

      container.read(settingsProvider.notifier).setAccent(AccentColor.green);
      container.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
      expect(prefs.getString('settings.accent'), 'green');
      expect(prefs.getString('settings.themeMode'), 'dark');
    });

    test('ad, baş harfler ve ilgi alanları saklanır', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);
      container
          .read(profileProvider.notifier)
          .completeOnboarding(name: '  esma nur ', interests: const [TechCategory.ai, TechCategory.mobile]);
      final profile = container.read(profileProvider);
      expect(profile.name, 'esma nur');
      expect(profile.firstName, 'esma');
      expect(profile.initials, 'EN');
      expect(profile.onboarded, isTrue);
      expect(prefs.getStringList('profile.interests'), ['ai', 'mobile']);
      expect(const Profile(name: 'ilayda', interests: [], onboarded: true).initials, 'İ');
      expect(const Profile(name: '', interests: [], onboarded: true).displayName, 'TechPulse okuru');
    });

    test('yazı boyutu sınırlarda kalır', () {
      expect(ReadingSize.small.smaller, ReadingSize.small);
      expect(ReadingSize.xlarge.larger, ReadingSize.xlarge);
      expect(ReadingSize.normal.larger, ReadingSize.large);
    });
  });

  group('Kişisel listeler', () {
    BookmarkRecord record(String key, DateTime at) =>
        BookmarkRecord(key: key, kind: BookmarkKind.news, payload: '{}', savedAt: at);

    test('okuma geçmişi en fazla 200 kayıt tutar', () async {
      final store = MemoryStore();
      for (var i = 0; i < historyLimit + 5; i++) {
        await store.saveRecord(UserList.history, record('news:$i', DateTime(2026, 1, 1).add(Duration(minutes: i))));
      }
      final records = await store.records(UserList.history);
      expect(records, hasLength(historyLimit));
      expect(records.first.key, 'news:${historyLimit + 4}');
      expect(records.any((r) => r.key == 'news:0'), isFalse);
    });

    test('okuma geçmişi 90 günden eski kayıtları siler', () async {
      final store = MemoryStore();
      await store.saveRecord(UserList.history, record('news:old', DateTime(2026, 1, 1)));
      await store.saveRecord(UserList.history, record('news:new', DateTime(2026, 6, 1)));
      final records = await store.records(UserList.history);
      expect(records.map((r) => r.key), ['news:new']);
    });

    test('listeler bağımsızdır; hepsini silmek her şeyi temizler', () async {
      final store = MemoryStore();
      await store.saveRecord(UserList.bookmarks, record('news:a', DateTime(2026)));
      await store.saveRecord(UserList.history, record('news:a', DateTime(2026)));
      await store.writeCache('news', '{}');
      await store.deleteRecord(UserList.bookmarks, 'news:a');
      expect(await store.records(UserList.bookmarks), isEmpty);
      expect(await store.records(UserList.history), hasLength(1));
      await store.clearAll();
      expect(await store.records(UserList.history), isEmpty);
      expect(await store.readCache('news'), isNull);
    });
  });

  group('Önce önbellek, sonra ağ', () {
    late MemoryStore store;
    late FakeSource source;
    var now = DateTime(2026, 11, 25, 12);
    final count = parseNews(fixture('news.json')).items.length;

    TechPulseRepository repo() => TechPulseRepository(source, store, clock: () => now);

    setUp(() {
      store = MemoryStore();
      source = FakeSource(allFixtures());
      now = DateTime(2026, 11, 25, 12);
    });

    test('önbellek yoksa ağdan gelir ve önbelleğe yazılır', () async {
      final snaps = await repo().watch(Endpoint.news, parseNews).toList();
      expect(snaps, hasLength(1));
      expect(snaps.single.fromCache, isFalse);
      expect(await store.readCache('news'), isNotNull);
    });

    test('önbellek önce, ağ sonra gelir', () async {
      await store.writeCache('news', fixture('news.json'));
      now = DateTime.now().add(const Duration(hours: 1));
      final snaps = await repo().watch(Endpoint.news, parseNews).toList();
      expect(snaps.map((s) => s.fromCache), [true, false]);
    });

    test('önbellek çok yeniyse ağa gidilmez', () async {
      await store.writeCache('news', fixture('news.json'));
      now = DateTime.now();
      final snaps = await repo().watch(Endpoint.news, parseNews).toList();
      expect(snaps, hasLength(1));
      expect(source.calls, 0);
    });

    test('ağ hatasında önbellek hata bilgisiyle gösterilir', () async {
      await store.writeCache('news', fixture('news.json'));
      now = DateTime.now().add(const Duration(hours: 1));
      source.offline = true;
      final snaps = await repo().watch(Endpoint.news, parseNews).toList();
      expect(snaps, hasLength(2));
      expect(snaps.last.isOffline, isTrue);
      expect(snaps.last.data.items, hasLength(count));
    });

    test('önbellek yoksa ve ağ yoksa türüyle birlikte hata fırlatır', () async {
      source.offline = true;
      await expectLater(
        repo().watch(Endpoint.news, parseNews).toList(),
        throwsA(isA<AppException>().having((e) => e.kind, 'kind', ErrorKind.offline)),
      );
    });

    test('bozuk ağ cevabı önbelleğe yazılmaz ve veri hatası sayılır', () async {
      source.files['news.json'] = '<html>hata</html>';
      await expectLater(
        repo().watch(Endpoint.news, parseNews).toList(),
        throwsA(isA<AppException>().having((e) => e.kind, 'kind', ErrorKind.data)),
      );
      expect(await store.readCache('news'), isNull);
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
