import 'package:flutter_test/flutter_test.dart';
import 'package:techpulse/core/formatting.dart';
import 'package:techpulse/data/data_source.dart';
import 'package:techpulse/data/local_store.dart';
import 'package:techpulse/data/models.dart';
import 'package:techpulse/data/repository.dart';
import 'package:techpulse/state/providers.dart';

import 'helpers.dart';

void main() {
  setUpAll(initTestLocale);

  group('Ayrıştırma', () {
    test('haberler okunur, güvenli olmayan bağlantılı kayıt atlanır', () {
      final feed = parseNews(fixture('news.json'));
      expect(feed.items, hasLength(7));
      expect(feed.items.any((n) => n.id == 'bad'), isFalse);
      expect(feed.generatedAt, isNotNull);
      final first = feed.items.first;
      expect(first.displayTitle, startsWith('Geliştiriciler için'));
      expect(first.category, NewsCategory.ai);
      expect(first.sourceKind, SourceKind.official);
    });

    test('çevrilmemiş haber özgün başlık ve açıklamayla gösterilir', () {
      final item = parseNews(fixture('news.json')).items.firstWhere((n) => n.id == 'n7');
      expect(item.titleTr, isNull);
      expect(item.displayTitle, "What's new in Jetpack Compose");
      expect(item.displaySummary, 'Compose brings faster lists and new APIs.');
      expect(item.hasDifferentOriginal, isFalse);
    });

    test('Hacker News puan ve yorum sayısı okunur', () {
      final item = parseNews(fixture('news.json')).items.firstWhere((n) => n.sourceId == 'hacker-news');
      expect(item.points, 412);
      expect(item.comments, 187);
      expect(item.discussionUrl, startsWith('https://news.ycombinator.com/'));
    });

    test('modeller, makaleler, projeler ve güvenlik kayıtları okunur', () {
      final models = parseModels(fixture('models.json')).items;
      expect(models.first.modality, Modality.vision);
      expect(models.first.parameters, 2100000000);
      final papers = parsePapers(fixture('papers.json')).items;
      expect(papers.first.authorLine, 'Ada Lovelace ve 2 yazar daha');
      final repos = parseRepos(fixture('repos.json')).items;
      expect(repos.first.isAi, isTrue);
      final vulns = parseSecurity(fixture('security.json')).items;
      expect(vulns.first.ransomware, isTrue);
      expect(vulns.last.displayTitle, 'Microsoft Windows Privilege Escalation Vulnerability');
      final meta = parseMeta(fixture('meta.json'));
      expect(meta.sources, hasLength(2));
      expect(meta.translatorModel, 'openai/gpt-4.1-mini');
    });

    test('bozuk zarf hata fırlatır, bozuk tek kayıt atlanır', () {
      expect(() => parseNews('[]'), throwsFormatException);
      expect(() => parseNews('{"items": 3}'), throwsFormatException);
      final feed = parseNews('{"items":[{"id":"x"}, 5, null]}');
      expect(feed.items, isEmpty);
    });
  });

  group('Biçimlendirme', () {
    test('Türkçe karakterlere duyarsız arama', () {
      expect(foldForSearch('Güvenlik İSTANBUL Işık'), 'guvenlik istanbul isik');
      expect(foldForSearch('ÇÖĞÜŞ'), 'cogus');
    });

    test('göreli zaman', () {
      final now = DateTime(2026, 11, 25, 12);
      expect(Fmt.relative(now.subtract(const Duration(seconds: 20)), now: now), 'az önce');
      expect(Fmt.relative(now.subtract(const Duration(minutes: 5)), now: now), '5 dk önce');
      expect(Fmt.relative(now.subtract(const Duration(hours: 3)), now: now), '3 sa önce');
      expect(Fmt.relative(now.subtract(const Duration(days: 1)), now: now), 'dün');
      expect(Fmt.relative(now.subtract(const Duration(days: 4)), now: now), '4 gün önce');
      expect(Fmt.relative(DateTime(2026, 11, 2), now: now), '2 Kas');
    });

    test('kısa sayılar', () {
      expect(Fmt.compact(950), '950');
      expect(Fmt.compact(1200), contains('1,2'));
      expect(Fmt.compact(2500000), contains('2,5'));
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
      expect(snaps.last.data.items, hasLength(7));
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
