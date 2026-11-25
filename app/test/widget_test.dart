import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techpulse/core/config.dart';
import 'package:techpulse/data/local_store.dart';
import 'package:techpulse/data/models.dart';
import 'package:techpulse/state/providers.dart';
import 'package:techpulse/ui/news/cards.dart';
import 'package:techpulse/ui/news/news_detail_screen.dart';
import 'package:techpulse/ui/radar/radar_screen.dart';
import 'package:techpulse/ui/search/search_screen.dart';
import 'package:techpulse/ui/shell.dart';

import 'helpers.dart';

void main() {
  late List<NewsItem> news;

  setUpAll(() async {
    await initTestLocale();
    // Gerçek yazı tipleri yüklenmezse test yazı tipi (Ahem) metinleri çok geniş çizer ve yerleşim değişir.
    await loadAppFonts();
    news = parseNews(fixture('news.json')).items;
  });

  NewsItem byCategory(String key) => news.firstWhere((n) => n.category.key == key && !n.hidden);

  Finder navLabel(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  testWidgets('Ana Sayfa marka, arama, öne çıkan haber ve bölümleri gösterir', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    expect(find.text('TechPulse'), findsOneWidget);
    expect(find.text(AppConfig.slogan), findsOneWidget);
    expect(find.text('Haber, teknoloji veya konu ara...'), findsOneWidget);
    expect(find.byType(FeaturedNewsCard), findsOneWidget);
    // En yüksek puanlı, görselli haber öne çıkar (önem 4, en yeni).
    expect(find.text(byCategory('industry').displayTitle), findsOneWidget);
    expect(find.text('Öne Çıkanlar', skipOffstage: false), findsOneWidget);
    expect(find.text('Son Gelişmeler', skipOffstage: false), findsOneWidget);
    for (final label in ['Ana Sayfa', 'Keşfet', 'Kaydedilenler', 'Profil']) {
      expect(navLabel(label), findsOneWidget);
    }
  });

  testWidgets('Konu filtresi listeyi daraltır; gizlenen haber hiç gösterilmez', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    final hidden = news.firstWhere((n) => n.hidden);
    expect(find.text(hidden.titleOriginal, skipOffstage: false), findsNothing);

    await tester.tap(find.text('Siber Güvenlik'));
    await settle(tester, frames: 4);

    expect(find.text(byCategory('security').displayTitle), findsOneWidget);
    expect(find.text(byCategory('industry').displayTitle, skipOffstage: false), findsNothing);
  });

  testWidgets('Haber ayrıntısı anlatımı, "Önce bunu bil" kutusunu ve kaynak düğmesini gösterir', (tester) async {
    usePhoneSize(tester);
    final store = MemoryStore();
    await tester.pumpWidget(await buildTestApp(store: store));
    await settle(tester);

    await tester.tap(find.byType(FeaturedNewsCard));
    await settle(tester, frames: 8);

    final item = byCategory('industry');
    expect(find.byType(NewsDetailScreen), findsOneWidget);
    expect(find.text(item.article!.intro), findsOneWidget);
    expect(find.text('Önce bunu bil', skipOffstage: false), findsOneWidget);
    expect(find.text(item.article!.sections.first.heading, skipOffstage: false), findsOneWidget);
    expect(find.text('Orijinal haberi kaynağından incele', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('temel alınarak', skipOffstage: false), findsOneWidget);
    // Açılan haber okuma geçmişine eklenir.
    expect((await store.records(UserList.history)).single.key, BookmarkRecord.keyFor(BookmarkKind.news, item.id));
  });

  testWidgets('Editörün henüz yazmadığı haberde dürüst bir not gösterilir', (tester) async {
    usePhoneSize(tester);
    final mt = news.firstWhere((n) => !n.aiWritten && !n.hidden);
    await tester.pumpWidget(await buildTestApp(home: NewsDetailScreen(item: mt)));
    await settle(tester);

    expect(find.text('Ayrıntılı anlatım hazırlanıyor', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('makine çevirisidir', skipOffstage: false), findsWidgets);
  });

  testWidgets('Kaydedilen haber Kaydedilenler sekmesinde görünür ve silinebilir', (tester) async {
    usePhoneSize(tester);
    final store = MemoryStore();
    await tester.pumpWidget(await buildTestApp(store: store));
    await settle(tester);

    await tester.tap(find.byTooltip('Kaydet').first);
    await settle(tester, frames: 4);
    expect((await store.records(UserList.bookmarks)).single.kind, BookmarkKind.news);

    await tester.tap(navLabel('Kaydedilenler'));
    await settle(tester, frames: 6);
    expect(find.text('1 kayıt'), findsOneWidget);
    expect(find.text('Daha sonra okumak için kaydettiğin haberler.'), findsOneWidget);

    await tester.tap(find.byTooltip('Kaydedilenlerden çıkar').last);
    await settle(tester, frames: 6);
    expect(await store.records(UserList.bookmarks), isEmpty);
    expect(find.text('Henüz haber kaydetmedin.'), findsOneWidget);
    expect(find.text('Haberlere göz at'), findsOneWidget);

    await settle(tester, frames: 30); // SnackBar zamanlayıcıları bitsin
  });

  testWidgets('İnternet yokken ve önbellek boşken anlaşılır mesaj gösterilir', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp(source: FakeSource(allFixtures(), offline: true)));
    await settle(tester);

    expect(find.text('İlk kullanım için internet gerekiyor'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });

  testWidgets('Önbellekteki veri internet olmadan gösterilir', (tester) async {
    usePhoneSize(tester);
    final store = MemoryStore();
    await store.writeCache('news', fixture('news.json'));
    final source = FakeSource(allFixtures(), offline: true);
    await tester.pumpWidget(await buildTestApp(store: store, source: source));
    await settle(tester);

    expect(find.text(byCategory('industry').displayTitle), findsOneWidget);
  });

  testWidgets('Arama Türkçe karakterlere duyarsızdır', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    await tester.tap(find.text('Haber, teknoloji veya konu ara...'));
    await settle(tester, frames: 6);
    expect(find.byType(SearchScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'fidye yazilimi');
    await settle(tester, frames: 5);

    expect(find.textContaining('Haberler · '), findsOneWidget);
    expect(find.text(byCategory('security').displayTitle), findsOneWidget);
  });

  testWidgets('Keşfet konuları, trendleri ve Yapay Zekâ Radarı\'nı gösterir', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    await tester.tap(navLabel('Keşfet'));
    await settle(tester, frames: 6);
    expect(find.text('Kategoriler'), findsOneWidget);
    expect(find.text('Uzay ve Bilim', skipOffstage: false), findsWidgets);
    expect(find.text('Trend Konular', skipOffstage: false), findsOneWidget);

    final tile = find.text('Trend Modeller', skipOffstage: false);
    await tester.ensureVisible(tile);
    await settle(tester, frames: 3);
    await tester.tap(tile);
    await settle(tester, frames: 8);
    expect(find.byType(RadarScreen), findsOneWidget);
    final model = parseModels(fixture('models.json')).items.first;
    expect(find.text(model.name), findsWidgets);
  });

  testWidgets('İlk açılışta ilgi alanı seçilir ve konular bu sırayla gösterilir', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp(onboarded: false));
    await settle(tester);

    expect(find.text("TechPulse'a hoş geldin"), findsOneWidget);
    final option = find.text('Mobil Teknolojiler', skipOffstage: false);
    await tester.ensureVisible(option);
    await settle(tester, frames: 3);
    await tester.tap(option);
    await settle(tester, frames: 3);
    await tester.tap(find.text('1 konuyla başla'));
    await settle(tester, frames: 8);

    expect(find.byType(AppShell), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('profile.interests'), ['mobile']);
    expect(prefs.getBool('profile.onboarded'), isTrue);
    // "Tümü"nden hemen sonra seçilen konu gelir.
    final tumu = tester.getTopLeft(find.text('Tümü')).dx;
    final mobile = tester.getTopLeft(find.text('Mobil Teknolojiler')).dx;
    final ai = tester.getTopLeft(find.text('Yapay Zekâ', skipOffstage: false).first).dx;
    expect(mobile, greaterThan(tumu));
    expect(ai, greaterThan(mobile));
  });

  testWidgets('Profil adı düzenlenir, istatistikler ve ayarlar gösterilir', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    await tester.tap(navLabel('Profil'));
    await settle(tester, frames: 6);
    expect(find.text('TechPulse okuru'), findsOneWidget);
    expect(find.text('Kaydedilen'), findsOneWidget);
    expect(find.text('Okunan'), findsOneWidget);
    expect(find.text('Favori'), findsOneWidget);
    expect(find.text('Bildirim Ayarları', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Profili düzenle'));
    await settle(tester, frames: 6);
    await tester.enterText(find.byType(TextField), 'Esma Nur');
    await tester.tap(find.text('Kaydet'));
    await settle(tester, frames: 6);

    expect(find.text('Esma Nur'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
  });

  testWidgets('Zil simgesi yenilikleri gösterir', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    await tester.tap(find.byTooltip(RegExp('^Yenilikler')));
    await settle(tester, frames: 8);
    expect(find.text('Yenilikler'), findsOneWidget);
    expect(find.text('Önemli gelişme'), findsWidgets);
  });
}
