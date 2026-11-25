import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:techpulse/core/categories.dart';
import 'package:techpulse/core/formatting.dart';
import 'package:techpulse/data/data_source.dart';
import 'package:techpulse/data/local_store.dart';
import 'package:techpulse/data/models.dart';
import 'package:techpulse/data/repository.dart';
import 'package:techpulse/state/providers.dart';
import 'package:techpulse/state/ranking.dart';

import 'helpers.dart';

void main() {
  setUpAll(initTestLocale);

  group('Ayrıştırma', () {
    test('yapay zekâ editörünün yazdığı haber tüm alanlarıyla okunur', () {
      final feed = parseNews(fixture('news.json'));
      expect(feed.items, hasLength(13));
      final first = feed.items.first;
      expect(first.aiWritten, isTrue);
      expect(first.category, TechCategory.ai);
      expect(first.imageUrl, startsWith('https://'));
      expect(first.article, isNotNull);
      expect(first.article!.sections, isNotEmpty);
      expect(first.article!.sections.first.paragraphs, isNotEmpty);
      expect(first.topics, contains('Character.AI'));
      expect(first.importance, inInclusiveRange(1, 5));
      expect(first.readingMinutes, greaterThan(0));
    });

    test('makine çevirisi kaydında ayrıntılı anlatım yoktur, gizli kayıt işaretlenir', () {
      final items = parseNews(fixture('news.json')).items;
      final mt = items.firstWhere((n) => n.sourceName == 'GitHub Blog');
      expect(mt.aiWritten, isFalse);
      expect(mt.article, isNull);
      expect(items.where((n) => n.hidden), hasLength(1));
    });

    test('Hacker News puan ve yorum sayısı okunur', () {
      final item = parseNews(fixture('news.json')).items.firstWhere((n) => n.sourceId == 'hacker-news');
      expect(item.points, isNotNull);
      expect(item.discussionUrl, startsWith('https://news.ycombinator.com/'));
    });

    test('önceki sürümün konu kimliği ve eksik alanlar tolere edilir', () {
      final feed = parseNews(jsonEncode({
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
          {'id': 'insecure', 'url': 'http://example.com/b', 'sourceId': 'x', 'sourceName': 'X', 'publishedAt': '2026-11-20T10:00:00Z', 'titleOriginal': 'T'},
        ],
      }));
      expect(feed.items, hasLength(1));
      final item = feed.items.single;
      expect(item.category, TechCategory.dev);
      expect(item.article, isNull);
      expect(item.topics, isEmpty);
      expect(item.imageUrl, isNull);
      expect(item.hidden, isFalse);
    });

    test('modeller, makaleler, projeler ve güvenlik kayıtları okunur', () {
      final models = parseModels(fixture('models.json')).items;
      expect(models.first.highlights, isA<List<String>>());
      expect(models.first.summaryTr, isNotNull);
      final papers = parsePapers(fixture('papers.json')).items;
      expect(papers.first.article, isNotNull);
      expect(papers.first.imageUrl, startsWith('https://'));
      final repos = parseRepos(fixture('repos.json')).items;
      expect(repos.first.imageUrl, startsWith('https://opengraph.githubassets.com/'));
      final vulns = parseSecurity(fixture('security.json')).items;
      expect(vulns.first.explanationTr, isNotNull);
      final meta = parseMeta(fixture('meta.json'));
      expect(meta.sources.length, greaterThan(30));
      expect(meta.editorModel, 'claude-haiku-5-5');
    });

    test('bozuk zarf hata fırlatır, bozuk tek kayıt atlanır', () {
      expect(() => parseNews('[]'), throwsFormatException);
      expect(() => parseNews('{"items": 3}'), throwsFormatException);
      final feed = parseNews('{"items":[{"id":"x"}, 5, null]}');
      expect(feed.items, isEmpty);
    });
  });

  group('Konular ve biçimlendirme', () {
    test('konu kimlikleri ve Türkçe büyük harf', () {
      expect(TechCategory.fromKey('security'), TechCategory.security);
      expect(TechCategory.fromKey('bilinmeyen'), TechCategory.industry);
      expect(TechCategory.tryKey('yok'), isNull);
      expect(trUpper('Siber güvenlik'), 'SİBER GÜVENLİK');
      expect(trUpper('Yapay Zekâ'), 'YAPAY ZEKÂ');
      expect(TechCategory.hardware.shortLabel, 'Donanım ve Çip');
    });

    test('Türkçe karakterlere duyarsız arama', () {
      expect(foldForSearch('Güvenlik İSTANBUL Işık'), 'guvenlik istanbul isik');
      expect(foldForSearch('ÇÖĞÜŞ'), 'cogus');
    });

    test('göreli zaman ve kısa sayılar', () {
      final now = DateTime(2026, 11, 25, 12);
      expect(Fmt.relative(now.subtract(const Duration(seconds: 20)), now: now), 'az önce');
      expect(Fmt.relative(now.subtract(const Duration(minutes: 5)), now: now), '5 dk önce');
      expect(Fmt.relative(now.subtract(const Duration(hours: 3)), now: now), '3 sa önce');
      expect(Fmt.relative(now.subtract(const Duration(days: 1)), now: now), 'dün');
      expect(Fmt.compact(950), '950');
      expect(Fmt.compact(1200), contains('1,2'));
    });
  });

  group('Sıralama', () {
    final news = parseNews(fixture('news.json')).items.where((n) => !n.hidden).toList();

    test('öne çıkan haber görselli olur, öne çıkanlar ve son gelişmeler tekrar etmez', () {
      final layout = HomeLayout.build(news, testNow);
      expect(layout.featured, isNotNull);
      expect(layout.featured!.imageUrl, isNotNull);
      expect(layout.highlights, hasLength(4));
      final ids = [layout.featured!.id, ...layout.highlights.map((n) => n.id), ...layout.latest.map((n) => n.id)];
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, hasLength(news.length));
    });

    test('ilgi alanındaki haberin puanı artar', () {
      final science = news.firstWhere((n) => n.category == TechCategory.science);
      expect(newsScore(science, testNow, interests: {TechCategory.science}), greaterThan(newsScore(science, testNow)));
    });

    test('önem puanı yüksek ve yeni haber önde gelir', () {
      final base = news.first;
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
    });

    test('trend konular etiketlerden çıkar, konuya göre haber bulunur', () {
      final topics = trendingTopics(news, testNow);
      expect(topics, isNotEmpty);
      expect(newsWithTopic(news, topics.first.label), isNotEmpty);
      expect(newsWithTopic(news, 'fidye yazilimi'), isNotEmpty);
    });
  });

  group('Kişisel listeler', () {
    test('okuma geçmişi en yeni 300 kaydı tutar', () async {
      final store = MemoryStore();
      for (var i = 0; i < historyLimit + 5; i++) {
        await store.saveRecord(
          UserList.history,
          BookmarkRecord(key: 'news:$i', kind: BookmarkKind.news, payload: '{}', savedAt: DateTime(2026, 1, 1).add(Duration(minutes: i))),
        );
      }
      final records = await store.records(UserList.history);
      expect(records, hasLength(historyLimit));
      expect(records.first.key, 'news:${historyLimit + 4}');
      expect(records.any((r) => r.key == 'news:0'), isFalse);
    });

    test('listeler birbirinden bağımsızdır', () async {
      final store = MemoryStore();
      final record = BookmarkRecord(key: 'news:a', kind: BookmarkKind.news, payload: '{}', savedAt: DateTime(2026));
      await store.saveRecord(UserList.bookmarks, record);
      await store.saveRecord(UserList.favorites, record);
      await store.deleteRecord(UserList.bookmarks, 'news:a');
      expect(await store.records(UserList.bookmarks), isEmpty);
      expect(await store.records(UserList.favorites), hasLength(1));
      await store.clearList(UserList.favorites);
      expect(await store.records(UserList.favorites), isEmpty);
    });
  });

  group('Önce önbellek, sonra ağ', () {
    late MemoryStore store;
    late FakeSource source;
    var now = DateTime(2026, 11, 25, 12);

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
      expect(snaps.last.data.items, hasLength(13));
    });

    test('önbellek yoksa ve ağ yoksa anlaşılır hata fırlatır', () async {
      source.offline = true;
      await expectLater(
        repo().watch(Endpoint.news, parseNews).toList(),
        throwsA(isA<AppException>().having((e) => e.offline, 'offline', isTrue)),
      );
    });

    test('bozuk ağ cevabı önbelleğe yazılmaz', () async {
      source.files['news.json'] = '<html>hata</html>';
      await expectLater(repo().watch(Endpoint.news, parseNews).toList(), throwsA(isA<AppException>()));
      expect(await store.readCache('news'), isNull);
    });
  });
}
