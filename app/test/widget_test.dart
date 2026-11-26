import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techpulse/core/brand.dart';
import 'package:techpulse/core/categories.dart';
import 'package:techpulse/data/data_source.dart';
import 'package:techpulse/data/local_store.dart';
import 'package:techpulse/data/models.dart';
import 'package:techpulse/data/repository.dart';
import 'package:techpulse/state/providers.dart';
import 'package:techpulse/ui/news/news_cards.dart';
import 'package:techpulse/ui/news/news_detail_screen.dart';
import 'package:techpulse/ui/news/news_list_screen.dart';
import 'package:techpulse/ui/news/story_view.dart';
import 'package:techpulse/ui/onboarding/onboarding_screen.dart';
import 'package:techpulse/ui/profile/info_pages.dart';
import 'package:techpulse/ui/profile/interests_screen.dart';
import 'package:techpulse/ui/radar/radar_details.dart';
import 'package:techpulse/ui/saved/record_tile.dart';
import 'package:techpulse/ui/search/search_screen.dart';
import 'package:techpulse/ui/shell.dart';
import 'package:techpulse/ui/widgets/state_views.dart';

import 'helpers.dart';

void main() {
  late List<NewsItem> news;

  setUpAll(() async {
    await initTestLocale();
    // Gerçek yazı tipleri yüklenmezse test yazı tipi metinleri çok geniş çizer ve yerleşim değişir.
    await loadAppFonts();
    news = parseNews(fixture('news.json')).items;
  });

  Finder navLabel(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(navLabel(label));
    await settle(tester, frames: 6);
  }

  testWidgets('Akış: selam, görünüm geçişi, filtre, manşet ve bölümler; zil yok', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp(prefs: {'profile.name': 'Esma Nur'}));
    await settle(tester);

    expect(find.byType(BrandLockup), findsOneWidget);
    expect(find.textContaining(', Esma'), findsOneWidget);
    expect(find.text('Sizin İçin'), findsOneWidget);
    expect(find.text('Tüm Gündem'), findsOneWidget);
    expect(find.byTooltip('Filtrele'), findsOneWidget);
    expect(find.byTooltip('Ara'), findsOneWidget);
    expect(find.byType(HeadlineCard), findsOneWidget);
    expect(find.text('Kısaca', skipOffstage: false), findsOneWidget);
    expect(find.text('Son gelişmeler', skipOffstage: false), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    for (final label in ['Akış', 'Keşfet', 'Radar', 'Kaydedilen', 'Profil']) {
      expect(navLabel(label), findsOneWidget);
    }
    // Gizlenen haber hiç gösterilmez.
    final hidden = news.firstWhere((n) => n.hidden);
    expect(find.text(hidden.displayTitle, skipOffstage: false), findsNothing);

    // Logoya dokunmak sayfayı yeniler (çökmeden).
    await tester.tap(find.byType(BrandLockup));
    await settle(tester, frames: 15);
    expect(find.byType(HeadlineCard), findsOneWidget);
  });

  testWidgets('İlgi alanları "Sizin İçin" akışını belirler; Tüm Gündem hepsini gösterir', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      await buildTestApp(
        prefs: {
          'profile.interests': ['security'],
        },
      ),
    );
    await settle(tester);

    List<TechCategory> shown() => [
      for (final c in tester.widgetList<HeadlineCard>(find.byType(HeadlineCard))) c.item.category,
      for (final c in tester.widgetList<BriefCard>(find.byType(BriefCard, skipOffstage: false))) c.item.category,
      for (final r in tester.widgetList<NewsRow>(find.byType(NewsRow, skipOffstage: false))) r.item.category,
    ];

    expect(tester.widget<HeadlineCard>(find.byType(HeadlineCard)).item.category, TechCategory.security);
    expect(shown().length, greaterThan(1));
    expect(shown().every((c) => c == TechCategory.security), isTrue);

    await tester.tap(find.text('Tüm Gündem'));
    await settle(tester, frames: 4);
    expect(shown().any((c) => c != TechCategory.security), isTrue);
  });

  testWidgets('Filtre: zaman aralığı seçilir, özet çubuğu görünür ve temizlenir', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    await tester.tap(find.byTooltip('Filtrele'));
    await settle(tester, frames: 6);
    expect(find.text('KONULAR'), findsOneWidget);
    await tester.tap(find.text('Son 24 saat'));
    await tester.tap(find.text('En yeni'));
    await settle(tester, frames: 2);
    await tester.tap(find.text('Uygula'));
    await settle(tester, frames: 6);

    expect(find.textContaining('Son 24 saat · En yeni'), findsOneWidget);
    expect(find.byType(HeadlineCard), findsNothing);
    await tester.tap(find.text('Temizle'));
    await settle(tester, frames: 4);
    expect(find.byType(HeadlineCard), findsOneWidget);
  });

  testWidgets('Haber: 30 saniyede oku, neden önemli, teknik anlatım, kavram çekmecesi ve kaynak', (tester) async {
    usePhoneSize(tester);
    final store = MemoryStore();
    final item = news.firstWhere((n) => n.story?.technical != null && n.story!.glossary.isNotEmpty);
    final story = item.story!;
    await tester.pumpWidget(
      await buildTestApp(
        store: store,
        home: NewsDetailScreen(item: item),
      ),
    );
    await settle(tester);

    expect(find.text(item.displayTitle), findsWidgets);
    expect(find.text('30 saniyede oku', skipOffstage: false), findsOneWidget);
    expect(find.text(story.tldr.first, skipOffstage: false), findsOneWidget);
    expect(find.text('Bu gelişme neden önemli?', skipOffstage: false), findsOneWidget);
    expect(find.text('Sade anlatım'), findsOneWidget);

    await tester.tap(find.text('Teknik derinlik'));
    await settle(tester, frames: 4);
    expect(find.text(ReadingLevel.technical.description), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is GlossaryParagraph && w.text == story.technical!.intro, skipOffstage: false),
      findsWidgets,
    );

    final scroll = find.descendant(of: find.byType(NewsDetailScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Bu haberdeki kavramlar'), 500, scrollable: scroll);
    await settle(tester, frames: 3);
    final term = story.glossary.first;
    await tester.scrollUntilVisible(find.text(term.term).last, 200, scrollable: scroll);
    await tester.tap(find.text(term.term).last);
    await settle(tester, frames: 6);
    expect(find.text('Kavram'), findsOneWidget);
    expect(find.text(term.definition), findsWidgets);
    await tester.tapAt(const Offset(200, 60)); // çekmeceyi kapat
    await settle(tester, frames: 6);

    await tester.scrollUntilVisible(find.text('Haberin aslını aç'), 400, scrollable: scroll);
    expect(find.byTooltip('Bağlantıyı kopyala'), findsOneWidget);
    // Açılan haber okuma geçmişine eklenir.
    expect((await store.records(UserList.history)).single.key, BookmarkRecord.keyFor(BookmarkKind.news, item.id));
  });

  testWidgets('Yazı boyutu A+ ile büyür ve ayarlara kaydedilir', (tester) async {
    usePhoneSize(tester);
    final item = news.firstWhere((n) => n.story != null);
    await tester.pumpWidget(await buildTestApp(home: NewsDetailScreen(item: item)));
    await settle(tester);

    await tester.tap(find.byTooltip('Yazı boyutu'));
    await settle(tester, frames: 6);
    await tester.tap(find.text('A+'));
    await settle(tester, frames: 3);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.readingSize'), 'large');
  });

  testWidgets('Anlatımı henüz hazırlanmamış haberde dürüst bir not gösterilir', (tester) async {
    usePhoneSize(tester);
    final mt = news.firstWhere((n) => !n.aiWritten && !n.hidden);
    await tester.pumpWidget(await buildTestApp(home: NewsDetailScreen(item: mt)));
    await settle(tester);

    expect(find.textContaining('ayrıntılı Türkçe anlatımı hazırlanıyor', skipOffstage: false), findsOneWidget);
  });

  testWidgets('Kaydedilen içerik listede görünür, kaydırınca silinir ve geri alınabilir', (tester) async {
    usePhoneSize(tester);
    final store = MemoryStore();
    await tester.pumpWidget(await buildTestApp(store: store));
    await settle(tester);

    await tester.tap(find.byTooltip('Kaydet').first);
    await settle(tester, frames: 4);
    expect((await store.records(UserList.bookmarks)).single.kind, BookmarkKind.news);

    await openTab(tester, 'Kaydedilen');
    expect(find.byType(RecordTile), findsOneWidget);
    // Sekmede sayı rozeti yok.
    expect(find.byType(Badge), findsNothing);

    await tester.drag(find.byType(RecordTile), const Offset(-500, 0));
    await settle(tester, frames: 16);
    expect(await store.records(UserList.bookmarks), isEmpty);
    expect(find.text('Henüz bir şey kaydetmediniz'), findsOneWidget);

    await tester.tap(find.text('Geri al'));
    await settle(tester, frames: 6);
    expect(await store.records(UserList.bookmarks), hasLength(1));
    await settle(tester, frames: 40); // SnackBar zamanlayıcıları bitsin
  });

  testWidgets('İnternet yokken ve önbellek boşken hata türüne uygun ekran gösterilir', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp(source: FakeSource(allFixtures(), offline: true)));
    await settle(tester);

    expect(find.text('İnternet bağlantısı yok'), findsOneWidget);
    expect(find.text('Yeniden dene'), findsOneWidget);
  });

  testWidgets('Önbellekteki haberler internet olmadan, uyarıyla gösterilir', (tester) async {
    usePhoneSize(tester);
    final store = MemoryStore();
    await store.writeCache('news', fixture('news.json'));
    final source = FakeSource(allFixtures(), offline: true);
    await tester.pumpWidget(await buildTestApp(store: store, source: source));
    await settle(tester);

    expect(find.byType(HeadlineCard), findsOneWidget);
  });

  testWidgets('Uyarı şeridi, telefona kaydedilen haberlerin gösterildiğini söyler', (tester) async {
    usePhoneSize(tester);
    final feed = parseNews(fixture('news.json'));
    final snapshot = Snapshot(
      feed,
      savedAt: testNow.subtract(const Duration(hours: 2)),
      fromCache: true,
      error: const AppException('İnternet bağlantısı kurulamadı.', kind: ErrorKind.offline),
    );
    await tester.pumpWidget(
      await buildTestApp(
        home: Scaffold(
          body: StatusBanner(snapshot: snapshot, generatedAt: feed.generatedAt),
        ),
      ),
    );
    await settle(tester, frames: 2);
    expect(find.textContaining('Çevrimdışısın. Telefona 2 sa önce kaydedilen haberler gösteriliyor.'), findsOneWidget);
  });

  testWidgets('Arama büyük/küçük harf ve Türkçe karakter farkı gözetmez', (tester) async {
    usePhoneSize(tester);
    final target = news.firstWhere((n) => n.story != null && n.category == TechCategory.security);
    final word = target.displayTitle.split(' ').firstWhere((w) => w.length > 5);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    await tester.tap(find.byTooltip('Ara'));
    await settle(tester, frames: 6);
    expect(find.byType(SearchScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), trUpper(word));
    await settle(tester, frames: 4);

    expect(find.textContaining('sonuç'), findsOneWidget);
    expect(find.text(target.displayTitle), findsOneWidget);
  });

  testWidgets('Keşfet: popüler haberler, gündemdeki konular ve dokuz konu', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    await openTab(tester, 'Keşfet');
    expect(find.text('Şu an popüler'), findsOneWidget);
    expect(find.byType(RankedNewsRow), findsWidgets);
    expect(find.text('Gündemdeki konular', skipOffstage: false), findsOneWidget);
    for (final c in TechCategory.values) {
      expect(find.text(c.shortLabel, skipOffstage: false), findsWidgets);
    }

    final tile = find.text(TechCategory.mobile.shortLabel, skipOffstage: false).last;
    await tester.ensureVisible(tile);
    await settle(tester, frames: 3);
    await tester.tap(tile);
    await settle(tester, frames: 8);
    expect(find.byType(NewsListScreen), findsOneWidget);
  });

  testWidgets('Radar: modeller ve projeler; proje sayfası README tanıtımı ve uyarı gösterir', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    await openTab(tester, 'Radar');
    final models = parseModels(fixture('models.json')).items..sort((a, b) => a.rank.compareTo(b.rank));
    expect(find.text(models.first.name), findsWidgets);

    await tester.tap(find.text('Projeler'));
    await settle(tester, frames: 8);
    final repo = parseRepos(fixture('repos.json')).items.firstWhere((r) => r.story != null);
    await tester.pumpWidget(await buildTestApp(home: RepoDetailScreen(repo: repo)));
    await settle(tester);
    expect(find.text('Bu proje ne yapıyor?'), findsOneWidget);
    expect(find.text('Neden ilgi görüyor?'), findsOneWidget);
    expect(find.text('Neler yapılabilir?', skipOffstage: false), findsOneWidget);
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Dikkat'), 300, scrollable: scroll);
    await tester.scrollUntilVisible(find.text('GitHub\'da aç'), 300, scrollable: scroll);
    expect(find.byTooltip('Bağlantıyı kopyala'), findsOneWidget);
  });

  testWidgets('İlk açılış: ad ve konu seçilir, akış adla selamlar', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp(onboarded: false));
    await settle(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Esma');
    await tester.tap(find.text('Devam'));
    await settle(tester, frames: 6);
    expect(find.text('Tüm konularla başla'), findsOneWidget);
    final option = find.text(TechCategory.mobile.shortLabel);
    await tester.ensureVisible(option);
    await tester.tap(option);
    await settle(tester, frames: 3);
    await tester.tap(find.text('Başla (1 konu)'));
    await settle(tester, frames: 10);

    expect(find.byType(AppShell), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('profile.interests'), ['mobile']);
    expect(prefs.getString('profile.name'), 'Esma');
    expect(find.textContaining(', Esma'), findsOneWidget);
  });

  testWidgets('Profil: ad düzenlenir, tema "Sistem"le başlar, uygulama rengi değişir; tekrar eden bölüm yok', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    await openTab(tester, 'Profil');
    expect(find.text('TechPulse okuru'), findsOneWidget);
    expect(find.text('İlgi alanları', skipOffstage: false), findsOneWidget);
    expect(find.text('Okuma geçmişi'), findsOneWidget);
    expect(find.text('Favori', skipOffstage: false), findsNothing);

    await tester.tap(find.text('TechPulse okuru'));
    await settle(tester, frames: 6);
    await tester.enterText(find.byType(TextField), 'Esma Nur');
    await tester.tap(find.text('Kaydet'));
    await settle(tester, frames: 8);
    expect(find.text('Esma Nur'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);

    final segmented = tester.widget<SegmentedButton<ThemeMode>>(find.byType(SegmentedButton<ThemeMode>));
    expect(segmented.selected, {ThemeMode.system});
    expect(segmented.segments.first.value, ThemeMode.system);
    final dark = find.text('Koyu');
    await tester.ensureVisible(dark);
    await tester.tap(dark);
    await settle(tester, frames: 4);
    final blue = find.byTooltip('Mavi');
    await tester.ensureVisible(blue);
    await tester.tap(blue);
    await settle(tester, frames: 4);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.themeMode'), 'dark');
    expect(prefs.getString('settings.accent'), 'blue');
    await settle(tester, frames: 40);
  });

  testWidgets('İlgi alanları yalnızca Kaydet ile uygulanır; kaydetmeden çıkarken sorulur', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);
    await openTab(tester, 'Profil');

    await tester.tap(find.text('Düzenle'));
    await settle(tester, frames: 8);
    expect(find.byType(InterestsScreen), findsOneWidget);
    expect(find.text('Değişiklik yok'), findsOneWidget);
    await tester.tap(find.text(TechCategory.ai.shortLabel));
    await settle(tester, frames: 3);
    expect(find.text('Kaydet (1 konu)'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester, frames: 6);
    expect(find.text('Değişiklikler kaydedilmedi'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await settle(tester, frames: 6);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('profile.interests'), isNull);

    await tester.tap(find.text('Kaydet (1 konu)'));
    await settle(tester, frames: 8);
    expect(find.byType(InterestsScreen), findsNothing);
    expect(prefs.getStringList('profile.interests'), ['ai']);
    await settle(tester, frames: 40);
  });

  testWidgets('Tüm verileri silmek onay ister ve ilk açılışa döner', (tester) async {
    usePhoneSize(tester);
    final store = MemoryStore();
    await store.saveRecord(
      UserList.bookmarks,
      BookmarkRecord(key: 'news:x', kind: BookmarkKind.news, payload: '{}', savedAt: testNow),
    );
    await tester.pumpWidget(await buildTestApp(store: store, prefs: {'profile.name': 'Esma'}));
    await settle(tester);
    await openTab(tester, 'Profil');

    final reset = find.text('Tüm verilerimi sil');
    await tester.scrollUntilVisible(reset, 300, scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(reset);
    await settle(tester, frames: 3);
    await tester.tap(reset);
    await settle(tester, frames: 6);
    expect(find.text('Bütün verileriniz silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Hepsini sil'));
    await settle(tester, frames: 10);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(await store.records(UserList.bookmarks), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('profile.name'), isNull);
  });

  testWidgets('Hakkında sayfasında kişi, okul veya model adı geçmez; kaynak kodu bağlantısı vardır', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp(home: const AboutScreen()));
    await settle(tester);

    for (final word in ['Beykent', 'Üniversite', 'Haiku', 'Claude', 'Anthropic', 'Hoca', 'Öğretim']) {
      expect(find.textContaining(word, skipOffstage: false), findsNothing, reason: word);
    }
    expect(find.text('Kaynak kodu', skipOffstage: false), findsOneWidget);
    expect(find.text('Logonun anlamı', skipOffstage: false), findsOneWidget);
  });
}
