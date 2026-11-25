import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techpulse/data/local_store.dart';
import 'package:techpulse/ui/news/news_card.dart';
import 'package:techpulse/ui/news/news_detail_screen.dart';
import 'package:techpulse/ui/search/search_screen.dart';

import 'helpers.dart';

void main() {
  setUpAll(() async {
    await initTestLocale();
    // Gerçek yazı tipleri yüklenmezse test yazı tipi (Ahem) metinleri çok geniş çizer ve yerleşim değişir.
    await loadAppFonts();
  });

  testWidgets('Gündem haberleri listeler ve öne çıkan kartı gösterir', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    expect(find.text('TechPulse'), findsOneWidget);
    expect(find.text('Öne çıkan'), findsOneWidget);
    expect(find.text('Geliştiriciler için daha hızlı bir akıl yürütme modeli tanıtıldı'), findsOneWidget);
    expect(find.textContaining('7 haber'), findsOneWidget);
  });

  testWidgets('Konu çipi listeyi filtreler', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    final chip = find.textContaining('Yazılım 2', skipOffstage: false);
    await tester.ensureVisible(chip);
    await settle(tester, frames: 3);
    await tester.tap(chip);
    await settle(tester, frames: 4);

    expect(find.text('Show HN: Rust ile yazılmış küçük, gömülü bir veritabanı'), findsOneWidget);
    expect(find.text('Geliştiriciler için daha hızlı bir akıl yürütme modeli tanıtıldı'), findsNothing);
    expect(find.textContaining('2 haber'), findsOneWidget);
    expect(find.text('Öne çıkan'), findsNothing);
  });

  testWidgets('Habere dokununca ayrıntı ve kaynak düğmesi açılır', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    await tester.tap(find.byType(NewsCard).first);
    await settle(tester, frames: 6);

    expect(find.byType(NewsDetailScreen), findsOneWidget);
    expect(find.textContaining('Kaynağında oku'), findsOneWidget);
    expect(find.textContaining('makine çevirisidir'), findsOneWidget);
  });

  testWidgets('Kaydedilen haber Kaydedilenler sekmesinde görünür', (tester) async {
    usePhoneSize(tester);
    final store = MemoryStore();
    await tester.pumpWidget(await buildTestApp(store: store));
    await settle(tester);

    await tester.tap(find.byTooltip('Kaydet').first);
    await settle(tester, frames: 4);
    expect((await store.bookmarks()).single.kind, BookmarkKind.news);

    await tester.tap(find.text('Kaydedilenler'));
    await settle(tester, frames: 6);
    expect(find.textContaining('Tümü 1'), findsOneWidget);
    expect(find.text('Geliştiriciler için daha hızlı bir akıl yürütme modeli tanıtıldı'), findsWidgets);

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
    // Önbellek taze olduğu için ağa hiç gidilmez; veri internetsiz de gösterilir.
    final source = FakeSource(allFixtures(), offline: true);
    await tester.pumpWidget(await buildTestApp(store: store, source: source));
    await settle(tester);

    expect(find.text('Geliştiriciler için daha hızlı bir akıl yürütme modeli tanıtıldı'), findsOneWidget);
  });

  testWidgets('Arama Türkçe karakterlere duyarsızdır', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    await tester.tap(find.byTooltip('Ara').first);
    await settle(tester, frames: 6);
    expect(find.byType(SearchScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'saldirganlar');
    await settle(tester, frames: 5);

    expect(find.textContaining('HABERLER · 1'), findsOneWidget);
    expect(find.text('Saldırganlar popüler VPN cihazlarındaki kritik açığı istismar ediyor'), findsOneWidget);
  });

  testWidgets('YZ Radarı modelleri Türkçe görev adıyla gösterir', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp());
    await settle(tester);

    await tester.tap(find.text('YZ Radarı'));
    await settle(tester, frames: 6);

    expect(find.text('Vision-Seg-2B'), findsOneWidget);
    expect(find.text('Görüntü bölütleme'), findsOneWidget);
  });
}
